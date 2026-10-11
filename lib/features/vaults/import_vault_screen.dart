import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../core/vault/vault_key_codec.dart';
import 'qr_scanner_page.dart';
import 'vaults_controller.dart';

/// Добавление ключа с другого устройства: вставка строки или сканирование QR.
class ImportVaultScreen extends StatefulWidget {
  const ImportVaultScreen({super.key});

  @override
  State<ImportVaultScreen> createState() => _ImportVaultScreenState();
}

class _ImportVaultScreenState extends State<ImportVaultScreen> {
  final _code = TextEditingController();
  InvalidVaultKeyException? _error;

  static bool get _scannerAvailable =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.addKey)),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_scannerAvailable) ...[
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l.scanQr),
                onPressed: _scan,
              ),
              const SizedBox(height: 24),
              Text(l.orPasteKey),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _code,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'TRM1.…',
                errorText: _error == null ? null : l.describeError(_error!),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _submit(_code.text),
              child: Text(l.add),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (code != null) await _submit(code);
  }

  Future<void> _submit(String code) async {
    try {
      final key = await context.read<VaultsController>().importCode(code);
      if (mounted) Navigator.pop(context, key);
    } on InvalidVaultKeyException catch (e) {
      setState(() => _error = e);
    }
  }
}
