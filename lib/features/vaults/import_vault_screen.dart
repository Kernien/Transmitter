import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  String? _error;

  static bool get _scannerAvailable =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить ключ')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_scannerAvailable) ...[
            FilledButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Сканировать QR-код'),
              onPressed: _scan,
            ),
            const SizedBox(height: 24),
            const Text('или вставьте ключ:'),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _code,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'TRM1.…',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => _submit(_code.text), child: const Text('Добавить')),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (code != null) await _submit(code);
  }

  Future<void> _submit(String code) async {
    try {
      final key = await context.read<VaultsController>().importCode(code);
      if (mounted) Navigator.pop(context, key);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }
}
