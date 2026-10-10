import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Сканирует QR-код камерой и возвращает его содержимое.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Наведите камеру на QR-код')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          final value = capture.barcodes
              .map((b) => b.rawValue)
              .whereType<String>()
              .firstOrNull;
          if (value == null) return;
          _done = true;
          Navigator.pop(context, value);
        },
      ),
    );
  }
}
