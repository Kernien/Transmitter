import '../../utils/device_name.dart';
import '../device_identity.dart';

DeviceNameSuggester createPlatformDeviceNameSuggester({
  String Function() workProfileLabel = englishWorkProfileLabel,
  String Function() browserName = englishBrowserName,
}) => const _FallbackSuggester();

class _FallbackSuggester implements DeviceNameSuggester {
  const _FallbackSuggester();

  @override
  Future<String> suggest() async => currentDeviceName();
}
