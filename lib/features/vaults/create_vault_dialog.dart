import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../core/storage/cloud_account.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';
import '../../core/vault/vault_key.dart';
import 'select_vault_icon_dialog.dart';
import 'vault_icon.dart';
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
  CloudAccount? _selectedAccount;
  int _maxFileSize = VaultKey.defaultMaxFileSize;
  bool _isEncrypted = true;
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    final connections = context.read<CloudConnectionService>();
    _provider = CloudProviderId.values
        .where(connections.isSupported)
        .firstOrNull;
    if (_provider != null) {
      _selectedAccount = connections.accountsFor(_provider!).firstOrNull;
    }
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
    final accounts = _provider == null
        ? const <CloudAccount>[]
        : connections.accountsFor(_provider!);

    return AlertDialog(
      title: Text(l.newKey),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final icon = await SelectVaultIconDialog.show(
                      context,
                      initialIcon: _selectedIcon,
                    );
                    if (icon != null) {
                      setState(() => _selectedIcon = icon.isEmpty ? null : icon);
                    }
                  },
                  child: Tooltip(
                    message: l.selectIconTitle,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: VaultIcon.buildWidget(
                        _selectedIcon,
                        isEncrypted: _isEncrypted,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _label,
                    autofocus: true,
                    decoration: InputDecoration(labelText: l.keyNameLabel),
                  ),
                ),
              ],
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
              onChanged: (p) => setState(() {
                _provider = p;
                if (p != null) {
                  final providerAccounts = connections.accountsFor(p);
                  _selectedAccount = providerAccounts.contains(_selectedAccount)
                      ? _selectedAccount
                      : providerAccounts.firstOrNull;
                } else {
                  _selectedAccount = null;
                }
              }),
            ),
            if (accounts.length > 1) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<CloudAccount>(
                initialValue: accounts.contains(_selectedAccount)
                    ? _selectedAccount
                    : accounts.firstOrNull,
                decoration: InputDecoration(labelText: l.accountLabel),
                items: [
                  for (final a in accounts)
                    DropdownMenuItem(
                      value: a,
                      child: Text(a.displayName),
                    ),
                ],
                onChanged: (a) => setState(() => _selectedAccount = a),
              ),
            ],
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
                  DropdownMenuItem(
                    value: size,
                    child: Text(l.sizeLimitOf(size)),
                  ),
              ],
              onChanged: (size) => setState(() => _maxFileSize = size!),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.encryptVaultLabel),
              subtitle: Text(l.encryptVaultSubtitle),
              value: _isEncrypted,
              onChanged: (v) => setState(() => _isEncrypted = v),
            ),
          ],
        ),
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
    final provider = _provider;
    if (provider == null) return;
    final accounts = context.read<CloudConnectionService>().accountsFor(provider);
    final account = _selectedAccount ?? accounts.firstOrNull;

    final key = await context.read<VaultsController>().create(
      label: _label.text,
      provider: provider,
      maxFileSize: _maxFileSize,
      isEncrypted: _isEncrypted,
      accountId: account?.id,
      accountEmail: account?.email,
      icon: _selectedIcon,
    );
    if (mounted) Navigator.pop(context, key);
  }
}
