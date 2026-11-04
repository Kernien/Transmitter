import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_lock_controller.dart';
import '../../app/l10n.dart';

Future<void> showAppLockSettings(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const AppLockSettingsScreen()));

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = context.watch<AppLockController>();
    return Scaffold(
      appBar: AppBar(title: Text(l.appLockTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.pin_outlined),
            title: Text(l.appLockTitle),
            subtitle: Text(
              controller.isEnabled
                  ? l.appLockEnabledSubtitle
                  : l.appLockDisabledSubtitle,
            ),
            value: controller.isEnabled,
            onChanged: _busy ? null : _togglePin,
          ),
          if (controller.isEnabled) ...[
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: Text(l.appLockChangePin),
              onTap: _busy ? null : _changePin,
            ),
            if (controller.biometricsAvailable)
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(l.appLockBiometrics),
                value: controller.biometricsEnabled,
                onChanged: _busy ? null : _toggleBiometrics,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _togglePin(bool enabled) async {
    if (enabled) {
      await _setNewPin();
      return;
    }
    if (!await _verifyCurrentPin()) return;
    await _run(() => context.read<AppLockController>().disable());
  }

  Future<void> _changePin() async {
    if (await _verifyCurrentPin()) await _setNewPin();
  }

  Future<bool> _verifyCurrentPin() async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => const _PinVerifyDialog(),
      ) ??
      false;

  Future<void> _setNewPin() async {
    final pin = await _showPinSetupDialog();
    if (pin == null || !mounted) return;
    final controller = context.read<AppLockController>();
    await _run(
      () => controller.setPin(pin, useBiometrics: controller.biometricsEnabled),
    );
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    await _run(
      () => context.read<AppLockController>().setBiometricsEnabled(enabled),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.describeError(error))));
  }

  Future<String?> _showPinSetupDialog() => showDialog<String>(
    context: context,
    builder: (_) => const _PinSetupDialog(),
  );
}

class _PinVerifyDialog extends StatefulWidget {
  const _PinVerifyDialog();

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.appLockCurrentPinTitle),
      content: TextField(
        controller: _pin,
        focusNode: _pinFocus,
        readOnly: _busy,
        autofocus: true,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        maxLength: AppLockController.pinLength,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: l.appLockEnterPinHint,
          errorText: _error,
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(l.save)),
      ],
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = context.l10n;
    final pin = _pin.text;
    if (!AppLockController.isValidPin(pin)) {
      setState(() {
        _pin.clear();
        _error = l.appLockPinInvalid;
      });
      _pinFocus.requestFocus();
      return;
    }
    final controller = context.read<AppLockController>();
    setState(() {
      _busy = true;
      _error = null;
      _pin.clear();
    });
    try {
      final accepted = await controller.verifyPin(pin);
      if (!mounted) return;
      if (accepted) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _busy = false;
        _pin.clear();
        _error = controller.lockoutSecondsRemaining > 0
            ? l.appLockWaitSeconds(controller.lockoutSecondsRemaining)
            : l.appLockWrongPin;
      });
      _pinFocus.requestFocus();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pin.clear();
        _error = l.describeError(error);
      });
      _pinFocus.requestFocus();
    }
  }
}

class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog();

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pin = TextEditingController();
  final _repeat = TextEditingController();
  final _pinFocus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _repeat.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const pinLength = AppLockController.pinLength;
    return AlertDialog(
      title: Text(l.appLockSetPinTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.appLockPinInstructions(pinLength)),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            focusNode: _pinFocus,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            maxLength: pinLength,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.appLockSetPinTitle,
              counterText: '',
            ),
          ),
          TextField(
            controller: _repeat,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            maxLength: pinLength,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.appLockRepeatPin,
              errorText: _error,
              counterText: '',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.save)),
      ],
    );
  }

  void _submit() {
    final l = context.l10n;
    final pin = _pin.text;
    final repeat = _repeat.text;
    if (!AppLockController.isValidPin(pin) ||
        !AppLockController.isValidPin(repeat)) {
      setState(() {
        _pin.clear();
        _repeat.clear();
        _error = l.appLockPinInvalid;
      });
      _pinFocus.requestFocus();
      return;
    }
    if (pin != repeat) {
      setState(() {
        _pin.clear();
        _repeat.clear();
        _error = l.appLockPinMismatch;
      });
      _pinFocus.requestFocus();
      return;
    }
    Navigator.pop(context, pin);
  }
}
