import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../core/auth/auth_browser.dart';
import '../../core/errors/app_error.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_adapter.dart';
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
  Object? _error;

  /// Номер попытки: результат отменённой попытки игнорируется.
  int _attempt = 0;

  // Вход по паролю (MEGA).
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _showPassword = false;
  bool _needsCode = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    final adapter = context.read<CloudConnectionService>().adapterFor(
      widget.provider,
    );
    final title = widget.provider.title;
    final withPassword = adapter is PasswordCloudAdapter;

    return Scaffold(
      appBar: AppBar(title: Text(l.connectTitle(title))),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              withPassword
                  ? l.passwordSignInExplanation(title)
                  : l.connectExplanation(title),
            ),
            const SizedBox(height: 24),
            if (!adapter.isConfigured)
              Text(
                l.cloudNotConfigured(title),
                style: TextStyle(color: errorColor),
              )
            else if (withPassword)
              ..._passwordForm(l, title)
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

  List<Widget> _passwordForm(AppLocalizations l, String title) => [
    AutofillGroup(
      child: Column(
        children: [
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.emailLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: !_showPassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: _needsCode
                ? TextInputAction.next
                : TextInputAction.done,
            onSubmitted: (_) {
              if (!_needsCode) _connectWithPassword();
            },
            decoration: InputDecoration(
              labelText: l.passwordLabel,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _showPassword ? l.hidePassword : l.showPassword,
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
        ],
      ),
    ),
    if (_needsCode) ...[
      const SizedBox(height: 16),
      TextField(
        controller: _code,
        enabled: !_busy,
        autofocus: true,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _connectWithPassword(),
        decoration: InputDecoration(
          labelText: l.secondFactorCodeLabel,
          border: const OutlineInputBorder(),
        ),
      ),
    ],
    const SizedBox(height: 24),
    if (_busy) ...[
      const Center(child: CircularProgressIndicator()),
      const SizedBox(height: 16),
      Text(l.signingIn, textAlign: TextAlign.center),
    ] else
      FilledButton.icon(
        icon: const Icon(Icons.login),
        label: Text(l.signInTo(title)),
        onPressed: _connectWithPassword,
      ),
  ];

  /// Понятные ошибки — как есть, остальные — «Не удалось подключиться: …».
  static String _errorText(AppLocalizations l, Object error) =>
      error is CodedError ? l.describeError(error) : l.connectFailed('$error');

  void _connect() {
    // connect() вызывается до setState и без await перед ним: в вебе окно
    // входа должно открыться прямо в обработчике нажатия.
    final future = context.read<CloudConnectionService>().connect(
      widget.provider,
    );
    _await(future);
  }

  void _connectWithPassword() {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;
    final future = context.read<CloudConnectionService>().connectWithPassword(
      widget.provider,
      email: email,
      password: password,
      secondFactorCode: _needsCode ? _code.text : null,
    );
    _await(future);
  }

  Future<void> _await(Future<void> future) async {
    final attempt = ++_attempt;
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
      if (error is SecondFactorRequiredException) _needsCode = true;
    });
  }

  void _cancel() => setState(() {
    _attempt++;
    _busy = false;
  });
}
