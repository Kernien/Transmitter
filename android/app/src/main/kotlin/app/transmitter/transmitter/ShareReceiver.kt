package app.transmitter.transmitter

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
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
    private val reader = ContentReader(activity.contentResolver)

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
            "files" to uris.map { reader.read(it, intent.type, limit) },
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

    companion object {
        const val CHANNEL = "app.transmitter/share"
    }
}
