package app.transmitter.transmitter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Выбор одного или нескольких фото/видео в Галерее — приложении для просмотра
 * фото по умолчанию (канал app.transmitter/gallery), а не в файловом менеджере.
 *
 * `pick(maxSize)` возвращает `null` (отмена) или список файлов в том же виде,
 * что и «Поделиться» (см. [ContentReader]).
 */
class GalleryPicker(private val activity: Activity, messenger: BinaryMessenger) {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val reader = ContentReader(
        activity.contentResolver,
        java.io.File(activity.cacheDir, "incoming"),
    )

    private var pending: MethodChannel.Result? = null
    private var maxSize: Long = 0

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "pick") return@setMethodCallHandler result.notImplemented()
            if (pending != null) return@setMethodCallHandler result.error("busy", "Gallery is already open", null)
            maxSize = (call.argument<Number>("maxSize") ?: 0).toLong()
            pending = result
            open()
        }
    }

    @Suppress("DEPRECATION")
    private fun open() {
        // Сначала — Галерея по умолчанию (ACTION_PICK по медиатеке), если её
        // нет — системный выбор фото и видео. В обоих случаях разрешён выбор
        // нескольких элементов.
        val gallery = Intent(Intent.ACTION_PICK).apply {
            setDataAndType(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image/*")
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        val fallback = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        for (intent in listOf(gallery, fallback)) {
            try {
                activity.startActivityForResult(intent, REQUEST_CODE)
                return
            } catch (_: ActivityNotFoundException) {
                // Пробуем следующий способ.
            }
        }
        finish { it.error("no_gallery", "No gallery app", null) }
    }

    /** Вызывается из MainActivity.onActivityResult; `true`, если это наш запрос. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val uris = if (resultCode == Activity.RESULT_OK) extractUris(data) else emptyList()
        if (uris.isEmpty()) {
            finish { it.success(null) }
            return true
        }
        val limit = maxSize
        io.execute {
            try {
                val files = uris.map { reader.read(it, null, limit) }
                main.post { finish { it.success(files) } }
            } catch (e: Exception) {
                main.post { finish { it.error("read_failed", e.message ?: e.toString(), null) } }
            }
        }
        return true
    }

    private fun extractUris(data: Intent?): List<Uri> {
        if (data == null) return emptyList()
        val clip = data.clipData
        if (clip != null && clip.itemCount > 0) {
            val uris = (0 until clip.itemCount).mapNotNull { clip.getItemAt(it)?.uri }
            if (uris.isNotEmpty()) return uris
        }
        data.data?.let { return listOf(it) }
        return streamListExtra(data)
    }

    @Suppress("DEPRECATION")
    private fun streamListExtra(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }) ?: emptyList()

    private fun finish(reply: (MethodChannel.Result) -> Unit) {
        val result = pending ?: return
        pending = null
        reply(result)
    }

    companion object {
        const val CHANNEL = "app.transmitter/gallery"
        private const val REQUEST_CODE = 47821
    }
}
