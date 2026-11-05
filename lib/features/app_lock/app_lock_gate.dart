import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_lock_controller.dart';
import '../../app/l10n.dart';
import '../../app/vault_session_factory.dart';
import '../../features/vaults/vaults_controller.dart';

/// Закрывает всё приложение при запуске, после долгого пребывания в фоне или
/// при отсутствии активности пользователя (в вебе).
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.controller,
    required this.vaults,
    required this.sessions,
    required this.navigatorKey,
    required this.child,
    this.trackInactivity = kIsWeb,
    this.inactivityTimeout = AppLockController.backgroundTimeout,
  });

  final AppLockController controller;
  final VaultsController vaults;
  final VaultSessionFactory sessions;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final bool trackInactivity;
  final Duration inactivityTimeout;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _biometricPromptOpen = false;
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.trackInactivity) {
      HardwareKeyboard.instance.addHandler(_onHardwareKeyEvent);
    }
    widget.controller.addListener(_onLockChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometrics();
      _startInactivityTimer();
    });
  }

  @override
  void didUpdateWidget(covariant AppLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onLockChanged);
      widget.controller.addListener(_onLockChanged);
    }
    if (oldWidget.trackInactivity != widget.trackInactivity) {
      if (widget.trackInactivity) {
        HardwareKeyboard.instance.addHandler(_onHardwareKeyEvent);
        _startInactivityTimer();
      } else {
        HardwareKeyboard.instance.removeHandler(_onHardwareKeyEvent);
        _stopInactivityTimer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.trackInactivity) {
      HardwareKeyboard.instance.removeHandler(_onHardwareKeyEvent);
    }
    _stopInactivityTimer();
    widget.controller.removeListener(_onLockChanged);
    super.dispose();
  }

  bool _onHardwareKeyEvent(KeyEvent event) {
    _onUserActivity();
    return false;
  }

  void _onUserActivity() {
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    if (!widget.trackInactivity ||
        !widget.controller.isEnabled ||
        widget.controller.isLocked) {
      _stopInactivityTimer();
      return;
    }
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(widget.inactivityTimeout, _onInactivityTimeout);
  }

  void _stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _onInactivityTimeout() {
    if (!mounted) return;
    if (widget.trackInactivity &&
        widget.controller.isEnabled &&
        !widget.controller.isLocked) {
      widget.controller.lock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _stopInactivityTimer();
      widget.controller.onBackground();
    } else if (state == AppLifecycleState.resumed) {
      widget.controller.onForeground();
      _tryBiometrics();
      if (!widget.controller.isLocked) {
        _startInactivityTimer();
      }
    }
  }

  void _onLockChanged() {
    if (mounted) setState(() {});
    _tryBiometrics();
    if (widget.controller.isLocked) {
      _stopInactivityTimer();
    } else {
      _startInactivityTimer();
    }
  }

  Future<void> _tryBiometrics() async {
    final controller = widget.controller;
    if (!mounted ||
        !controller.isLocked ||
        !controller.biometricsEnabled ||
        !controller.biometricsAvailable ||
        _biometricPromptOpen ||
        !controller.claimAutomaticBiometricAttempt()) {
      return;
    }
    _biometricPromptOpen = true;
    try {
      await controller.unlockWithBiometrics(
        reason: context.l10n.appLockBiometricReason,
      );
    } finally {
      _biometricPromptOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      Widget content = Stack(
        fit: StackFit.expand,
        children: [
          // Пока приложение закрыто, лента под экраном блокировки не должна
          // получать ввод с клавиатуры (Tab, Enter) и читаться программами
          // экранного доступа: на ПК фокус иначе уходит под экран ПИН-кода.
          ExcludeFocus(
            excluding: widget.controller.isLocked,
            child: ExcludeSemantics(
              excluding: widget.controller.isLocked,
              child: widget.child,
            ),
          ),
          if (widget.controller.isLocked)
            Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => AppLockScreen(
                    controller: widget.controller,
                    vaults: widget.vaults,
                    sessions: widget.sessions,
                    navigatorKey: widget.navigatorKey,
                  ),
                ),
              ],
            ),
        ],
      );

      if (widget.trackInactivity) {
        content = Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _onUserActivity(),
          onPointerMove: (_) => _onUserActivity(),
          onPointerHover: (_) => _onUserActivity(),
          onPointerSignal: (_) => _onUserActivity(),
          child: content,
        );
      }

      return content;
    },
  );
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.controller,
    required this.vaults,
    required this.sessions,
    required this.navigatorKey,
  });

  final AppLockController controller;
  final VaultsController vaults;
  final VaultSessionFactory sessions;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  String? _message;
  bool _busy = false;
  bool _confirmingRecovery = false;

  @override
  void dispose() {
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = widget.controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 48),
                        const SizedBox(height: 20),
                        Text(
                          l.appLockTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 24),
                        if (controller.canRecover)
                          Text(
                            l.appLockSettingsCorrupt,
                            textAlign: TextAlign.center,
                          )
                        else ...[
                          TextField(
                            controller: _pin,
                            focusNode: _pinFocus,
                            readOnly: _busy,
                            autofocus: true,
                            obscureText: true,
                            enableSuggestions: false,
                            autocorrect: false,
                            maxLength: AppLockController.pinLength,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            onSubmitted: (_) => _unlockWithPin(),
                            decoration: InputDecoration(
                              labelText: l.appLockEnterPinTitle,
                              hintText: l.appLockEnterPinHint,
                              errorText: _message,
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _busy ? null : _unlockWithPin,
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l.appLockUnlock),
                          ),
                          if (controller.biometricsEnabled &&
                              controller.biometricsAvailable)
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : _unlockWithBiometrics,
                              icon: const Icon(Icons.fingerprint),
                              label: Text(l.appLockBiometrics),
                            ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy ? null : _showRecoveryConfirmation,
                          child: Text(l.appLockForgotPin),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_confirmingRecovery)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: AlertDialog(
                      title: Text(l.appLockRecoveryTitle),
                      content: Text(l.appLockRecoveryMessage),
                      actions: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _confirmingRecovery = false,
                                ),
                          child: Text(l.cancel),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : _confirmRecovery,
                          child: Text(l.appLockRecover),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _unlockWithPin() async {
    if (_busy) return;
    final controller = widget.controller;
    final l = context.l10n;
    final pin = _pin.text;
    if (!AppLockController.isValidPin(pin)) {
      setState(() {
        _pin.clear();
        _message = l.appLockPinInvalid;
      });
      _pinFocus.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _pin.clear();
    });
    try {
      final accepted = await controller.verifyPin(pin);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin.clear();
        _message = accepted
            ? null
            : controller.lockoutSecondsRemaining > 0
            ? l.appLockWaitSeconds(controller.lockoutSecondsRemaining)
            : l.appLockWrongPin;
      });
      if (!accepted) _pinFocus.requestFocus();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin.clear();
        _message = l.describeError(error);
      });
      _pinFocus.requestFocus();
    }
  }

  Future<void> _unlockWithBiometrics() async {
    setState(() => _busy = true);
    try {
      await widget.controller.unlockWithBiometrics(
        reason: context.l10n.appLockBiometricReason,
      );
    } on Object catch (error) {
      if (mounted) setState(() => _message = context.l10n.describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showRecoveryConfirmation() {
    setState(() => _confirmingRecovery = true);
  }

  Future<void> _confirmRecovery() async {
    final l = context.l10n;
    final navigator = widget.navigatorKey.currentState;
    setState(() => _busy = true);
    final messenger = navigator == null
        ? null
        : ScaffoldMessenger.maybeOf(navigator.context);
    try {
      await widget.vaults.clearLocalKeys();
      widget.sessions.clearSessions();
      navigator?.popUntil((route) => route.isFirst);
      await widget.controller.disable();
      if (messenger?.mounted ?? false) {
        messenger!.showSnackBar(
          SnackBar(content: Text(l.appLockRecoveryComplete)),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = l.describeError(error);
        });
      }
    }
  }
}
