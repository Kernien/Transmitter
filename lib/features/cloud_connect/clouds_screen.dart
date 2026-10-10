import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets/content_width.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';
import 'connect_cloud_screen.dart';

/// Подключённые облака: вход и выход на этом устройстве.
class CloudsScreen extends StatelessWidget {
  const CloudsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final connections = context.watch<CloudConnectionService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Облака')),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          children: [
            for (final provider in CloudProviderId.values)
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(provider.title),
                subtitle: Text(_status(connections, provider)),
                trailing: !connections.isSupported(provider)
                    ? null
                    : connections.isConnected(provider)
                    ? TextButton(
                        onPressed: () => connections.disconnect(provider),
                        child: const Text('Выйти'),
                      )
                    : FilledButton.tonal(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ConnectCloudScreen(provider: provider),
                          ),
                        ),
                        child: const Text('Войти'),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  static String _status(CloudConnectionService c, CloudProviderId p) {
    if (!c.isSupported(p)) return 'Скоро';
    return c.isConnected(p) ? 'Подключено' : 'Не подключено';
  }
}
