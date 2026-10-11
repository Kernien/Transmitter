import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../core/auth/auth_browser.dart';
import '../../core/errors/app_error.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';

/// Вход в облако на этом устройстве. Возвращает `true` при успехе.
class ConnectCloudScreen extends StatefulWidget {
  const ConnectCloudScreen({super.key, required this.provider});

  final CloudProviderId provider;

  @override
  State<ConnectCloudScreen> createState() => _ConnectCloudScreenState();
}

class _ConnectCloudScreenState extends State<ConnectCloudScreen> {
  bool _busy = false;
  Object? _error;

  /// Номер попытки: результат отменённой попытки игнорируется.
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    final adapter = context.read<CloudConnectionService>().adapterFor(
      widget.provider,
    );
    final title = widget.provider.title;

    return Scaffold(
      appBar: AppBar(title: Text(l.connectTitle(title))),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l.connectExplanation(title)),
            const SizedBox(height: 24),
            if (!adapter.isConfigured)
              Text(
                l.cloudNotConfigured(title),
                style: TextStyle(color: errorColor),
              )
            else if (_busy) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(l.finishSignInInBrowser, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(onPressed: _cancel, child: Text(l.cancel)),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.login),
                label: Text(l.signInTo(title)),
                onPressed: _connect,
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_errorText(l, _error!), style: TextStyle(color: errorColor)),
            ],
          ],
        ),
      ),
    );
  }

  /// Понятные ошибки — как есть, остальные — «Не удалось подключиться: …».
  static String _errorText(AppLocalizations l, Object error) =>
      error is CodedError ? l.describeError(error) : l.connectFailed('$error');

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
    Object? error;
    try {
      await future;
    } on AuthCancelledException {
      error = null;
    } catch (e) {
      error = e;
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
