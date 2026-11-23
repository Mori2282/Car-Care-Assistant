import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../domain/models/vin.dart';

class VinScannerPage extends StatefulWidget {
  const VinScannerPage({super.key});

  @override
  State<VinScannerPage> createState() => _VinScannerPageState();
}

class _VinScannerPageState extends State<VinScannerPage> {
  bool _completed = false;

  void _detect(BarcodeCapture capture) {
    if (_completed || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = normalizeVin(barcode.rawValue ?? '');
      final vin =
          value.startsWith('I') && value.length == 18
              ? value.substring(1)
              : value;
      if (isVin(vin)) {
        _completed = true;
        Navigator.of(context).pop(vin);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Сканировать VIN')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: _detect,
              errorBuilder:
                  (context, error, child) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Камера недоступна. Проверьте разрешение или введите VIN вручную.',
                      ),
                    ),
                  ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Наведите камеру на штрихкод или QR-код с VIN.'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ввести вручную'),
          ),
        ],
      ),
    ),
  );
}
