import 'package:flutter/material.dart';

class VinScannerWidget extends StatefulWidget {
  final Function(String vin) onVinScanned;

  const VinScannerWidget({super.key, required this.onVinScanned});

  @override
  State<VinScannerWidget> createState() => _VinScannerWidgetState();
}

class _VinScannerWidgetState extends State<VinScannerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _simulateScan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isScanning = false);
      const mockVins = [
        'WBA31AY050FP12345',
        '5YJ3E1EB8LF654321',
        'WAUZZZ8K9DA012345',
        'JHMFA1F82BS098765'
      ];
      final scannedVin = (List.from(mockVins)..shuffle()).first;
      widget.onVinScanned(scannedVin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  _isScanning ? 'Идет сканирование VIN-кода...' : 'Наведите камеру на VIN-код или ПТС',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _simulateScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(_isScanning ? 'Сканирование...' : 'Захватить VIN (Mock)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                )
              ],
            ),
          ),
          if (_isScanning)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Positioned(
                  top: 10 + (_animationController.value * 150),
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.8),
                          blurRadius: 6,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
