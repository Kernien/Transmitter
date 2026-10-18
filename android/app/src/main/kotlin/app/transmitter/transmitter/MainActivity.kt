package app.transmitter.transmitter

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var shareReceiver: ShareReceiver? = null
    private var galleryPicker: GalleryPicker? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        DeviceInfoChannel(this, messenger)
        FileOpener(this, messenger)
        galleryPicker = GalleryPicker(this, messenger)
        shareReceiver = ShareReceiver(this, messenger).also {
            it.handle(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        shareReceiver?.handle(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (galleryPicker?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
