import 'dart:io';

import 'package:flutter/services.dart';

import '../../utils/device_name.dart';
import '../device_identity.dart';

DeviceNameSuggester createPlatformDeviceNameSuggester() => Platform.isAndroid
    ? const AndroidDeviceNameSuggester()
    : const DesktopDeviceNameSuggester();

/// Имя телефона из «Настройки → О телефоне»; в рабочем профиле — с пометкой.
/// Нативная часть — DeviceInfoChannel.kt.
class AndroidDeviceNameSuggester implements DeviceNameSuggester {
  const AndroidDeviceNameSuggester();

  static const MethodChannel _channel = MethodChannel('app.transmitter/device');

  @override
  Future<String> suggest() async {
    final info = Map<String, Object?>.from(
      await _channel.invokeMethod<Map>('info') ?? const {},
    );
    return format(
      name: info['name'] as String? ?? 'Android',
      workProfile: info['workProfile'] == true,
    );
  }

  /// Вынесено для тестов.
  static String format({required String name, required bool workProfile}) =>
      workProfile ? '$name · рабочий' : name;
}

/// Имя компьютера в сети (например, «Windows · DESKTOP-1A2B3C»).
class DesktopDeviceNameSuggester implements DeviceNameSuggester {
  const DesktopDeviceNameSuggester();

  @override
  Future<String> suggest() async {
    final host = Platform.localHostname.trim();
    return host.isEmpty
        ? currentDeviceName()
        : '${currentDeviceName()} · $host';
  }
}
