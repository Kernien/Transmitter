import '../device_identity.dart';

DeviceNameSuggester createPlatformDeviceNameSuggester({
  String Function() workProfileLabel = englishWorkProfileLabel,
  String Function() browserName = englishBrowserName,
}) => WebDeviceNameSuggester(browserName);

class WebDeviceNameSuggester implements DeviceNameSuggester {
  const WebDeviceNameSuggester([this.browserName = englishBrowserName]);

  /// «Браузер» / «Browser» — на текущем языке интерфейса.
  final String Function() browserName;

  @override
  Future<String> suggest() async => browserName();
}
