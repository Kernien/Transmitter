package app.transmitter.transmitter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Свой провайдер: у share_plus есть свой FileProvider, имена не должны совпадать. */
class OpenFileProvider : FileProvider()

/**
 * «Открыть в другом приложении» (канал app.transmitter/open): файл из
 * временной папки (cache/open/…) передаётся выбранному приложению по
 * content://-ссылке с правом только на чтение.
 */
class FileOpener(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "open") return@setMethodCallHandler result.notImplemented()
            val path = call.argument<String>("path")
            val mimeType = call.argument<String>("mimeType") ?: "*/*"
            if (path == null) return@setMethodCallHandler result.error("bad_args", "No path", null)
            try {
                val uri = FileProvider.getUriForFile(
                    activity, "${activity.packageName}.open", File(path),
                )
                val view = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                activity.startActivity(Intent.createChooser(view, null))
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error("no_app", "No app can open this file", null)
            } catch (e: Exception) {
                result.error("open_failed", e.message, null)
            }
        }
    }

    companion object {
        const val CHANNEL = "app.transmitter/open"
    }
}
