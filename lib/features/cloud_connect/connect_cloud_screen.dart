import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets/content_width.dart';
import '../../core/auth/auth_browser.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';
import '../../core/storage/cloud_storage.dart';

/// Вход в облако на этом устройстве. Возвращает `true` при успехе.
class ConnectCloudScreen extends StatefulWidget {
  const ConnectCloudScreen({super.key, required this.provider});

  final CloudProviderId provider;

  @override
  State<ConnectCloudScreen> createState() => _ConnectCloudScreenState();
}

class _ConnectCloudScreenState extends State<ConnectCloudScreen> {
  bool _busy = false;
  String? _error;

  /// Номер попытки: результат отменённой попытки игнорируется.
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final adapter = context.read<CloudConnectionService>().adapterFor(
      widget.provider,
    );
    final title = widget.provider.title;

    return Scaffold(
      appBar: AppBar(title: Text('Подключить $title')),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Войдите в $title на этом устройстве. Приложение получит доступ '
              'только к своей отдельной папке, остальные файлы ему не видны. '
              'Всё содержимое шифруется до отправки.',
            ),
            const SizedBox(height: 24),
            if (!adapter.isConfigured)
              Text(
                adapter.configurationHint,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_busy) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              const Text(
                'Завершите вход в открывшемся окне браузера…',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _cancel, child: const Text('Отмена')),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: Text('Войти в $title'),
                onPressed: _connect,
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final attempt = ++_attempt;
    // connect() вызывается до setState и без await перед ним: в вебе окно
    // входа должно открыться прямо в обработчике нажатия.
    final future = context.read<CloudConnectionService>().connect(
      widget.provider,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      await future;
    } on AuthCancelledException {
      error = null;
    } on AuthException catch (e) {
      error = e.message;
    } on StorageException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Не удалось подключиться: $e';
    }
    if (!mounted || attempt != _attempt) return;
    if (error == null &&
        context.read<CloudConnectionService>().isConnected(widget.provider)) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  void _cancel() => setState(() {
    _attempt++;
    _busy = false;
  });
}
