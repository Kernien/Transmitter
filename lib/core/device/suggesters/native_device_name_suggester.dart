import 'dart:io';

import 'package:flutter/services.dart';

import '../../utils/device_name.dart';
import '../device_identity.dart';

DeviceNameSuggester createPlatformDeviceNameSuggester({
  String Function() workProfileLabel = englishWorkProfileLabel,
  String Function() browserName = englishBrowserName,
}) => Platform.isAndroid
    ? AndroidDeviceNameSuggester(workProfileLabel: workProfileLabel)
    : const DesktopDeviceNameSuggester();

/// Имя телефона из «Настройки → О телефоне»; в рабочем профиле — с пометкой
/// [workProfileLabel] («рабочий» / «work»). Нативная часть — DeviceInfoChannel.kt.
class AndroidDeviceNameSuggester implements DeviceNameSuggester {
  const AndroidDeviceNameSuggester({
    this.workProfileLabel = englishWorkProfileLabel,
  });

  static const MethodChannel _channel = MethodChannel('app.transmitter/device');

  /// Пометка рабочего профиля на текущем языке интерфейса.
  final String Function() workProfileLabel;

  @override
  Future<String> suggest() async {
    final info = Map<String, Object?>.from(
      await _channel.invokeMethod<Map>('info') ?? const {},
    );
    return format(
      name: info['name'] as String? ?? 'Android',
      workProfile: info['workProfile'] == true,
      workProfileLabel: workProfileLabel(),
    );
  }

  /// Вынесено для тестов.
  static String format({
    required String name,
    required bool workProfile,
    String workProfileLabel = 'work',
  }) => workProfile ? '$name · $workProfileLabel' : name;
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
