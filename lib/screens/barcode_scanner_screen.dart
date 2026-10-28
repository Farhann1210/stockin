import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pindai Barcode')),
    body: MobileScanner(
      onDetect: (capture) {
        if (_handled) return;
        final barcode = capture.barcodes
            .map((item) => item.rawValue)
            .whereType<String>()
            .firstOrNull;
        if (barcode == null || barcode.isEmpty) return;
        _handled = true;
        Navigator.of(context).pop(barcode);
      },
    ),
  );
}
