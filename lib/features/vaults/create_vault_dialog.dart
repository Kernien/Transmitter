import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';
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
    final l = context.l10n;
    final connections = context.read<CloudConnectionService>();
    return AlertDialog(
      title: Text(l.newKey),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            decoration: InputDecoration(labelText: l.keyNameLabel),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<CloudProviderId>(
            initialValue: _provider,
            decoration: InputDecoration(labelText: l.cloudLabel),
            items: [
              for (final p in CloudProviderId.values)
                DropdownMenuItem(
                  value: p,
                  enabled: connections.isSupported(p),
                  child: Text(
                    connections.isSupported(p)
                        ? p.title
                        : l.cloudComingSoon(p.title),
                  ),
                ),
            ],
            onChanged: (p) => setState(() => _provider = p),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _maxFileSize,
            decoration: InputDecoration(
              labelText: l.maxFileSizeLabel,
              helperText: l.maxFileSizeHelp,
              helperMaxLines: 2,
            ),
            items: [
              for (final size in VaultKey.maxFileSizeOptions)
                DropdownMenuItem(value: size, child: Text(l.sizeLimitOf(size))),
            ],
            onChanged: (size) => setState(() => _maxFileSize = size!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _provider == null ? null : _submit,
          child: Text(l.create),
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
