import '../device_identity.dart';

DeviceNameSuggester createPlatformDeviceNameSuggester() =>
    const WebDeviceNameSuggester();

class WebDeviceNameSuggester implements DeviceNameSuggester {
  const WebDeviceNameSuggester();

  @override
  Future<String> suggest() async => 'Браузер';
}
