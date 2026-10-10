package app.transmitter.transmitter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Принимает содержимое из системного меню «Поделиться» (ACTION_SEND и
 * ACTION_SEND_MULTIPLE) и передаёт его в Dart по каналу app.transmitter/share.
 *
 * Dart вызывает `ready(maxSize)`, когда готов принимать данные; до этого
 * пришедшие намерения откладываются. Файлы читаются в фоновом потоке; файлы
 * больше maxSize не читаются — передаётся только их имя и размер.
 */
class ShareReceiver(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private var maxSize: Long = 0
    private var dartReady = false
    private var pending: Intent? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    maxSize = (call.argument<Number>("maxSize") ?: 0).toLong()
                    dartReady = true
                    pending?.let { deliver(it) }
                    pending = null
                    result.success(null)
                }
                // Вернуть пользователя в приложение, из которого он поделился.
                "moveToBack" -> {
                    activity.moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Вызывается для намерения, с которым запущена или открыта активность. */
    fun handle(intent: Intent?) {
        if (intent == null || !isShare(intent)) return
        // Повторный запуск из «Недавних» не должен отправлять то же самое ещё раз.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        if (dartReady) deliver(intent) else pending = intent
    }

    private fun isShare(intent: Intent) =
        intent.action == Intent.ACTION_SEND || intent.action == Intent.ACTION_SEND_MULTIPLE

    private fun deliver(intent: Intent) {
        val limit = maxSize
        io.execute {
            val payload = try {
                extract(intent, limit)
            } catch (e: Exception) {
                mapOf("error" to (e.message ?: e.toString()))
            }
            main.post { channel.invokeMethod("onShare", payload) }
        }
    }

    private fun extract(intent: Intent, limit: Long): Map<String, Any?> {
        val uris = when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(streamExtra(intent))
            else -> streamListExtra(intent)
        }
        return mapOf(
            "text" to intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString(),
            "subject" to intent.getStringExtra(Intent.EXTRA_SUBJECT),
            "files" to uris.map { readFile(it, intent.type, limit) },
        )
    }

    private fun readFile(uri: Uri, fallbackType: String?, limit: Long): Map<String, Any?> {
        var name: String? = null
        var size: Long = -1
        activity.contentResolver.query(
            uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameIndex >= 0) name = cursor.getString(nameIndex)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
            }
        }
        val mimeType = activity.contentResolver.getType(uri) ?: fallbackType
        val fileName = name ?: uri.lastPathSegment ?: "file"

        if (size > limit) {
            return mapOf("name" to fileName, "mimeType" to mimeType, "size" to size, "bytes" to null)
        }
        val bytes = activity.contentResolver.openInputStream(uri)?.use { input ->
            if (size >= 0) {
                // Размер известен: читаем сразу в массив нужной длины, без
                // промежуточного буфера (важно для файлов до 100 МБ).
                readExactly(input, size.toInt())
            } else {
                // Размер неизвестен — читаем с ограничением.
                val data = input.readNBytesCompat(limit + 1)
                if (data.size > limit) null else data
            }
        }
        return mapOf(
            "name" to fileName,
            "mimeType" to mimeType,
            "size" to (bytes?.size?.toLong() ?: maxOf(size, limit + 1)),
            "bytes" to bytes,
        )
    }

    @Suppress("DEPRECATION")
    private fun streamExtra(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableExtra(Intent.EXTRA_STREAM)

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)) ?: emptyList()

    /** Ровно [size] байт; `null`, если поток оказался длиннее (размер был неверным). */
    private fun readExactly(input: java.io.InputStream, size: Int): ByteArray? {
        val data = ByteArray(size)
        var offset = 0
        while (offset < size) {
            val read = input.read(data, offset, size - offset)
            if (read < 0) return data.copyOf(offset)
            offset += read
        }
        return if (input.read() < 0) data else null
    }

    private fun java.io.InputStream.readNBytesCompat(max: Long): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (total < max) {
            val read = read(buffer, 0, minOf(buffer.size.toLong(), max - total).toInt())
            if (read < 0) break
            out.write(buffer, 0, read)
            total += read
        }
        return out.toByteArray()
    }

    companion object {
        const val CHANNEL = "app.transmitter/share"
    }
}
