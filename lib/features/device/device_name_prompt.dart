import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/device/device_identity.dart';
import 'device_name_dialog.dart';

/// При первом запуске (пока имя не задано) один раз предлагает назвать
/// устройство. «Позже» — спросим при следующем запуске.
class DeviceNamePrompt extends StatefulWidget {
  const DeviceNamePrompt({super.key, required this.child});

  final Widget child;

  @override
  State<DeviceNamePrompt> createState() => _DeviceNamePromptState();
}

class _DeviceNamePromptState extends State<DeviceNamePrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !context.read<DeviceIdentity>().isNamed) {
        showDeviceNameDialog(context, firstRun: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
