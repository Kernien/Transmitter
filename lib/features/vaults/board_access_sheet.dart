import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/l10n.dart';
import '../../app/vault_session_factory.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/storage/cloud_provider_id.dart';
import '../../core/vault/vault_key.dart';
import 'board_access_controller.dart';

/// «Доступ на чтение»: открыть базу как публичную доску, показать ключ
/// читателя или закрыть доступ.
Future<void> showBoardAccessSheet(BuildContext context, VaultKey key) {
  final sessions = context.read<VaultSessionFactory>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => BoardAccessController(
        publisher: () => sessions.openBoard(key),
        label: key.label,
      )..load(),
      child: _BoardAccessView(label: key.label, provider: key.provider),
    ),
  );
}

class _BoardAccessView extends StatelessWidget {
  const _BoardAccessView({required this.label, required this.provider});

  final String label;
  final CloudProviderId provider;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final board = context.watch<BoardAccessController>();
    final error = board.error;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.boardAccessTitle, style: theme.textTheme.titleLarge),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            ...switch (board.status) {
              BoardAccessStatus.loading => [const CircularProgressIndicator()],
              BoardAccessStatus.unsupported => [Text(l.boardUnsupported)],
              BoardAccessStatus.failed => [
                Text(
                  l.describeError(error!),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: board.load, child: Text(l.retry)),
              ],
              BoardAccessStatus.closed => _closed(context, board),
              BoardAccessStatus.open => _open(context, board),
            },
            if (error != null && board.status != BoardAccessStatus.failed) ...[
              const SizedBox(height: 12),
              Text(
                l.describeError(error),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (board.needsSignIn) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.login),
                label: Text(l.boardSignInAgain(provider.title)),
                // Вход начинается прямо в обработчике нажатия: в браузере
                // иначе окно входа заблокируют.
                onPressed: board.isBusy
                    ? null
                    : () => board.signInAgain(
                        context.read<CloudConnectionService>().connect(
                          provider,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _closed(BuildContext context, BoardAccessController board) {
    final l = context.l10n;
    return [
      Text(l.boardIntro, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      FilledButton.icon(
        icon: board.isBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.public),
        label: Text(l.boardOpenAccess),
        onPressed: board.isBusy ? null : board.openAccess,
      ),
    ];
  }

  List<Widget> _open(BuildContext context, BoardAccessController board) {
    final l = context.l10n;
    final code = board.readerCode!;
    return [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: QrImageView(data: code, size: 240),
      ),
      const SizedBox(height: 16),
      SelectableText(code, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.copy),
        label: Text(l.copyKey),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l.keyCopied)));
          }
        },
      ),
      const SizedBox(height: 16),
      Text(
        l.boardReaderHint,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 20),
      TextButton.icon(
        icon: board.isBusy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.public_off),
        label: Text(l.boardCloseAccess),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: board.isBusy ? null : () => _close(context, board),
      ),
    ];
  }

  Future<void> _close(BuildContext context, BoardAccessController board) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.boardCloseTitle),
        content: Text(l.boardCloseText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.boardCloseAccess),
          ),
        ],
      ),
    );
    if (confirmed == true && await board.closeAccess()) {
      messenger.showSnackBar(SnackBar(content: Text(l.boardClosed)));
    }
  }
}
