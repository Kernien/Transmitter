import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/cache_settings.dart';
import '../../app/l10n.dart';

/// «Место на устройстве»: сколько занято, лимит на сохранённые файлы,
/// очистка.
Future<void> showStorageDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _StorageDialog());

class _StorageDialog extends StatefulWidget {
  const _StorageDialog();

  @override
  State<_StorageDialog> createState() => _StorageDialogState();
}

class _StorageDialogState extends State<_StorageDialog> {
  late Future<int> _used = context.read<CacheSettings>().usedBytes();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = context.watch<CacheSettings>();
    return AlertDialog(
      title: Text(l.storageTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.storageIntro),
          const SizedBox(height: 16),
          FutureBuilder(
            future: _used,
            builder: (context, snapshot) => Text(
              l.storageUsed(
                snapshot.hasData ? l.fileSize(snapshot.data!) : '…',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: settings.limitBytes,
            decoration: InputDecoration(
              labelText: l.storageLimit,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final bytes in CacheSettings.limitOptions)
                DropdownMenuItem(value: bytes, child: Text(l.fileSize(bytes))),
            ],
            onChanged: (bytes) async {
              if (bytes == null) return;
              await settings.setLimit(bytes);
              setState(() => _used = settings.usedBytes());
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await settings.clearFiles();
            setState(() => _used = settings.usedBytes());
          },
          child: Text(l.storageClear),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.closeAction),
        ),
      ],
    );
  }
}
