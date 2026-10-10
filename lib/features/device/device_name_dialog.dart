import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/device/device_identity.dart';

/// Диалог имени устройства. Возвращает `true`, если имя сохранено.
///
/// [firstRun] — первый запуск: поясняет, зачем нужно имя, и подставляет
/// подсказку (например, «Redmi 10 · рабочий»).
Future<bool> showDeviceNameDialog(
  BuildContext context, {
  bool firstRun = false,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: !firstRun,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<DeviceIdentity>(),
      child: _DeviceNameDialog(firstRun: firstRun),
    ),
  );
  return saved ?? false;
}

class _DeviceNameDialog extends StatefulWidget {
  const _DeviceNameDialog({required this.firstRun});

  final bool firstRun;

  @override
  State<_DeviceNameDialog> createState() => _DeviceNameDialogState();
}

class _DeviceNameDialogState extends State<_DeviceNameDialog> {
  final _name = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final identity = context.read<DeviceIdentity>();
    if (identity.isNamed) {
      _name.text = identity.name;
    } else {
      identity.suggestName().then((suggestion) {
        if (mounted && _name.text.isEmpty) {
          _name.text = suggestion;
          _name.selection = TextSelection(
            baseOffset: 0,
            extentOffset: suggestion.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.firstRun ? 'Как назвать это устройство?' : 'Имя устройства',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.firstRun
                ? 'Этим именем будут подписаны записи с этого устройства — так '
                      'на других устройствах будет понятно, откуда они пришли.'
                : 'Новые записи будут подписаны новым именем; старые сохранят прежнее.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: DeviceIdentity.maxLength,
            decoration: InputDecoration(
              labelText: 'Например, «Redmi — рабочий» или «Ноутбук»',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(widget.firstRun ? 'Позже' : 'Отмена'),
        ),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Future<void> _save() async {
    try {
      await context.read<DeviceIdentity>().rename(_name.text);
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError {
      setState(() => _error = 'Введите имя');
    }
  }
}
