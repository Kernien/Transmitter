import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../core/device/device_identity.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/vault/vault_key.dart';
import '../cloud_connect/clouds_screen.dart';
import '../cloud_connect/connect_cloud_screen.dart';
import '../device/device_name_dialog.dart';
import '../feed/feed_screen.dart';
import '../settings/language_dialog.dart';
import 'board_access_sheet.dart';
import 'create_vault_dialog.dart';
import 'import_vault_screen.dart';
import 'share_vault_sheet.dart';
import 'vaults_controller.dart';

/// Главный экран: список ключей баз.
class VaultsScreen extends StatelessWidget {
  const VaultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final vaults = context.watch<VaultsController>().vaults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transmitter'),
        actions: [
          IconButton(
            tooltip: l.language,
            icon: const Icon(Icons.translate),
            onPressed: () => showLanguageDialog(context),
          ),
          IconButton(
            tooltip: l.deviceNameTooltip(context.watch<DeviceIdentity>().name),
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => showDeviceNameDialog(context),
          ),
          IconButton(
            tooltip: l.clouds,
            icon: const Icon(Icons.cloud_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CloudsScreen())),
          ),
          IconButton(
            tooltip: l.addKey,
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _import(context),
          ),
        ],
      ),
      body: ContentWidth(
        child: vaults.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                itemCount: vaults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _VaultTile(vault: vaults[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.newKey),
        onPressed: () => _create(context),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final key = await showDialog<VaultKey>(
      context: context,
      builder: (_) => const CreateVaultDialog(),
    );
    if (key != null && context.mounted) {
      await showShareVaultSheet(context, key);
    }
  }

  Future<void> _import(BuildContext context) async {
    final key = await Navigator.of(context).push<VaultKey>(
      MaterialPageRoute(builder: (_) => const ImportVaultScreen()),
    );
    if (key != null && context.mounted) await openVault(context, key);
  }
}

/// Открывает базу. Если облако ещё не подключено, сначала просит войти.
Future<void> openVault(BuildContext context, VaultKey key) async {
  final connections = context.read<CloudConnectionService>();
  final messenger = ScaffoldMessenger.of(context);

  if (!connections.isSupported(key.provider)) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.providerNotSupported(key.provider.title)),
      ),
    );
    return;
  }
  if (!connections.isConnected(key.provider)) {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConnectCloudScreen(provider: key.provider),
      ),
    );
    if (connected != true || !context.mounted) return;
  }
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => FeedScreen(vaultKey: key)));
}

class _VaultTile extends StatelessWidget {
  const _VaultTile({required this.vault});

  final VaultKey vault;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final connected = context.watch<CloudConnectionService>().isConnected(
      vault.provider,
    );
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.key)),
      title: Text(vault.label.isEmpty ? l.untitled : vault.label),
      subtitle: Text(
        connected
            ? l.vaultSubtitleConnected(
                vault.provider.title,
                l.sizeLimitOf(vault.maxFileSize),
              )
            : l.vaultSubtitleNotConnected(vault.provider.title),
      ),
      onTap: () => openVault(context, vault),
      trailing: PopupMenuButton<_VaultAction>(
        onSelected: (action) => _onAction(context, action),
        itemBuilder: (_) => [
          PopupMenuItem(value: _VaultAction.share, child: Text(l.showKeyQr)),
          PopupMenuItem(
            value: _VaultAction.board,
            child: Text(l.boardAccessAction),
          ),
          PopupMenuItem(value: _VaultAction.rename, child: Text(l.rename)),
          PopupMenuItem(
            value: _VaultAction.remove,
            child: Text(l.removeFromDevice),
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, _VaultAction action) async {
    final controller = context.read<VaultsController>();
    switch (action) {
      case _VaultAction.share:
        await showShareVaultSheet(context, vault);
      case _VaultAction.board:
        await showBoardAccessSheet(context, vault);
      case _VaultAction.rename:
        final label = await _askLabel(context, vault.label);
        if (label != null) await controller.rename(vault, label);
      case _VaultAction.remove:
        if (await _confirmRemove(context)) await controller.remove(vault);
    }
  }

  Future<String?> _askLabel(BuildContext context, String current) {
    final l = context.l10n;
    final text = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.nameTitle),
        content: TextField(controller: text, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmRemove(BuildContext context) async {
    final l = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeKeyTitle),
        content: Text(l.removeKeyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

enum _VaultAction { share, board, rename, remove }

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(context.l10n.vaultsEmpty, textAlign: TextAlign.center),
      ),
    );
  }
}
