import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../core/storage/cloud_account.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';
import 'connect_cloud_screen.dart';

/// Подключённые облака и аккаунты: добавление, переименование и выход.
class CloudsScreen extends StatelessWidget {
  const CloudsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final connections = context.watch<CloudConnectionService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.clouds)),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          children: [
            for (final provider in CloudProviderId.values)
              if (provider.isCloud)
                if (!connections.isSupported(provider))
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(provider.title),
                  subtitle: Text(l.statusSoon),
                )
              else
                _providerCard(context, theme, l, connections, provider),
          ],
        ),
      ),
    );
  }

  Widget _providerCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l,
    CloudConnectionService connections,
    CloudProviderId provider,
  ) {
    final accounts = connections.accountsFor(provider);
    final isConnected = accounts.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(
                isConnected ? Icons.cloud_done : Icons.cloud_outlined,
                color: isConnected ? theme.colorScheme.primary : null,
              ),
              title: Text(
                provider.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isConnected ? l.statusConnected : l.statusNotConnected,
              ),
              trailing: FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(isConnected ? l.addAccount : l.signIn),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConnectCloudScreen(provider: provider),
                  ),
                ),
              ),
            ),
            if (accounts.isNotEmpty) ...[
              const Divider(height: 1),
              for (final account in accounts)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(
                    account.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle:
                      account.email != null && account.email != account.label
                      ? Text(account.email!)
                      : null,
                  trailing: PopupMenuButton<String>(
                    tooltip: '',
                    onSelected: (action) {
                      if (action == 'rename') {
                        _renameDialog(context, connections, account);
                      } else if (action == 'disconnect') {
                        _disconnectDialog(context, connections, account);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 20),
                            const SizedBox(width: 12),
                            Text(l.renameAccount),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'disconnect',
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout,
                              size: 20,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              l.signOut,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static Future<void> _renameDialog(
    BuildContext context,
    CloudConnectionService connections,
    CloudAccount account,
  ) async {
    final l = context.l10n;
    final controller = TextEditingController(text: account.displayName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.renameAccount),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.accountNameLabel,
          ),
          onSubmitted: (_) => Navigator.of(dialogCtx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await connections.renameAccount(account.id, controller.text.trim());
    }
  }

  static Future<void> _disconnectDialog(
    BuildContext context,
    CloudConnectionService connections,
    CloudAccount account,
  ) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.disconnectAccountConfirm(account.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.signOut),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await connections.disconnectAccount(account.id);
    }
  }
}
