package app.transmitter.transmitter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Выбор фото или видео в Галерее — приложении для просмотра фото по
 * умолчанию (канал app.transmitter/gallery), а не в файловом менеджере.
 *
 * `pick(maxSize)` возвращает `null` (отмена) или файл в том же виде, что и
 * «Поделиться» (см. [ContentReader]).
 */
class GalleryPicker(private val activity: Activity, messenger: BinaryMessenger) {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val reader = ContentReader(activity.contentResolver)

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
        // нет — системный выбор фото и видео.
        val gallery = Intent(Intent.ACTION_PICK).apply {
            setDataAndType(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "image/*")
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
        }
        val fallback = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
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
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            finish { it.success(null) }
            return true
        }
        val limit = maxSize
        io.execute {
            try {
                val file = reader.read(uri, null, limit)
                main.post { finish { it.success(file) } }
            } catch (e: Exception) {
                main.post { finish { it.error("read_failed", e.message ?: e.toString(), null) } }
            }
        }
        return true
    }

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
