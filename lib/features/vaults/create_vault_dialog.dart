import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';
import '../../core/utils/format_size.dart';
import '../../core/vault/vault_key.dart';
import 'vaults_controller.dart';

/// Создание нового ключа: название и облако, где будет лежать база.
class CreateVaultDialog extends StatefulWidget {
  const CreateVaultDialog({super.key});

  @override
  State<CreateVaultDialog> createState() => _CreateVaultDialogState();
}

class _CreateVaultDialogState extends State<CreateVaultDialog> {
  final _label = TextEditingController();
  CloudProviderId? _provider;
  int _maxFileSize = VaultKey.defaultMaxFileSize;

  @override
  void initState() {
    super.initState();
    final connections = context.read<CloudConnectionService>();
    _provider = CloudProviderId.values
        .where(connections.isSupported)
        .firstOrNull;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connections = context.read<CloudConnectionService>();
    return AlertDialog(
      title: const Text('Новый ключ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Название, например «Работа»',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CloudProviderId>(
            initialValue: _provider,
            decoration: const InputDecoration(labelText: 'Облако'),
            items: [
              for (final p in CloudProviderId.values)
                DropdownMenuItem(
                  value: p,
                  enabled: connections.isSupported(p),
                  child: Text(
                    connections.isSupported(p) ? p.title : '${p.title} (скоро)',
                  ),
                ),
            ],
            onChanged: (p) => setState(() => _provider = p),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _maxFileSize,
            decoration: const InputDecoration(
              labelText: 'Максимальный размер файла',
              helperText:
                  'Действует на всех устройствах с этим ключом.\n'
                  'Изменить его потом нельзя.',
              helperMaxLines: 2,
            ),
            items: [
              for (final size in VaultKey.maxFileSizeOptions)
                DropdownMenuItem(
                  value: size,
                  child: Text(formatSizeLimit(size)),
                ),
            ],
            onChanged: (size) => setState(() => _maxFileSize = size!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _provider == null ? null : _submit,
          child: const Text('Создать'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final key = await context.read<VaultsController>().create(
      label: _label.text,
      provider: _provider!,
      maxFileSize: _maxFileSize,
    );
    if (mounted) Navigator.pop(context, key);
  }
}
