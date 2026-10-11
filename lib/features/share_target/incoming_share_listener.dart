import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/vault_session_factory.dart';
import '../../core/share/incoming_share.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../vaults/vaults_controller.dart';
import 'share_target_controller.dart';
import 'share_target_screen.dart';

/// Открывает экран «Отправить в Transmitter», когда пользователь делится
/// чем-то из другого приложения. Оборачивает главный экран.
class IncomingShareListener extends StatefulWidget {
  const IncomingShareListener({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingShareListener> createState() => _IncomingShareListenerState();
}

class _IncomingShareListenerState extends State<IncomingShareListener> {
  StreamSubscription<SharedContent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = context.read<IncomingShareSource>().shares.listen(
      _open,
      onError: _showError,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _open(SharedContent content) async {
    final connections = context.read<CloudConnectionService>();
    final sessions = context.read<VaultSessionFactory>();
    final source = context.read<IncomingShareSource>();
    final messenger = ScaffoldMessenger.of(context);
    final sentText = context.l10n.sent;

    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ShareTargetController(
            content: content,
            vaults: context.read<VaultsController>().vaults,
            isUsable: (key) =>
                connections.isSupported(key.provider) &&
                connections.isConnected(key.provider),
            openVault: sessions.open,
          ),
          child: const ShareTargetScreen(),
        ),
      ),
    );
    if (sent == true) {
      messenger.showSnackBar(SnackBar(content: Text(sentText)));
      await source.returnToSourceApp();
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final l = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.shareReceiveFailed(l.describeError(error)))),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
