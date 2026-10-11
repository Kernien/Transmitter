import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';
import 'connect_cloud_screen.dart';

/// Подключённые облака: вход и выход на этом устройстве.
class CloudsScreen extends StatelessWidget {
  const CloudsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final connections = context.watch<CloudConnectionService>();
    return Scaffold(
      appBar: AppBar(title: Text(l.clouds)),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          children: [
            for (final provider in CloudProviderId.values)
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(provider.title),
                subtitle: Text(_status(l, connections, provider)),
                trailing: !connections.isSupported(provider)
                    ? null
                    : connections.isConnected(provider)
                    ? TextButton(
                        onPressed: () => connections.disconnect(provider),
                        child: Text(l.signOut),
                      )
                    : FilledButton.tonal(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ConnectCloudScreen(provider: provider),
                          ),
                        ),
                        child: Text(l.signIn),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  static String _status(
    AppLocalizations l,
    CloudConnectionService c,
    CloudProviderId p,
  ) {
    if (!c.isSupported(p)) return l.statusSoon;
    return c.isConnected(p) ? l.statusConnected : l.statusNotConnected;
  }
}
