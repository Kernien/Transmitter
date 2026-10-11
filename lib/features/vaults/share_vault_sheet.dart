import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/l10n.dart';
import '../../core/vault/vault_key.dart';
import 'vaults_controller.dart';

/// Показывает ключ в виде QR-кода и строки для копирования.
Future<void> showShareVaultSheet(BuildContext context, VaultKey key) {
  final code = context.read<VaultsController>().exportCode(key);
  final l = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              key.label.isEmpty ? l.vaultKeyTitle : key.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
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
              l.keyWarning,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
