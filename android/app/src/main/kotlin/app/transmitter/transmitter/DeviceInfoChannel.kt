package app.transmitter.transmitter

import android.app.Activity
import android.os.Build
import android.os.Process
import android.os.UserManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Сведения для подсказки имени устройства (канал app.transmitter/device):
 * имя телефона из «Настройки → О телефоне» и признак рабочего профиля
 * (например, созданного в Shelter).
 */
class DeviceInfoChannel(private val activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "info") {
                result.success(
                    mapOf(
                        "name" to deviceName(),
                        "workProfile" to isWorkProfile(),
                    ),
                )
            } else {
                result.notImplemented()
            }
        }
    }

    /** Имя, заданное пользователем в настройках; иначе — модель. */
    private fun deviceName(): String {
        val userName = Settings.Global.getString(activity.contentResolver, Settings.Global.DEVICE_NAME)
        if (!userName.isNullOrBlank()) return userName
        val model = Build.MODEL ?: ""
        val manufacturer = Build.MANUFACTURER ?: ""
        return if (model.startsWith(manufacturer, ignoreCase = true)) model
        else "$manufacturer $model".trim()
    }

    private fun isWorkProfile(): Boolean =
        if (Build.VERSION.SDK_INT >= 30) {
            activity.getSystemService(UserManager::class.java).isManagedProfile
        } else {
            // До Android 11 нет прямого API: рабочий профиль — не основной пользователь.
            Process.myUserHandle().hashCode() != 0
        }

    companion object {
        const val CHANNEL = "app.transmitter/device"
    }
}
