import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/nhtsa_api_service.dart';
import '../cubit/vehicle_cubit.dart';
import '../widgets/vin_scanner_widget.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _mileageController = TextEditingController();
  final _vinController = TextEditingController();
  final _yearController = TextEditingController();

  final _apiService = NhtsaApiService();
  bool _isLoadingApi = false;

  /// Отправка VIN в реальный REST API через Dio
  Future<void> _fetchVehicleSpecs(String vin) async {
    setState(() => _isLoadingApi = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Запрос спецификации в NHTSA REST API (США)...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final specs = await _apiService.decodeVin(vin);

    if (mounted) {
      setState(() {
        _isLoadingApi = false;
        if (specs != null) {
          _brandController.text = specs['brand'];
          _modelController.text = specs['model'];
          _yearController.text = specs['year'].toString();
        }
      });

      if (specs != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Данные получены: ${specs['brand']} ${specs['model']} (${specs['year']})'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавление автомобиля'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Захват VIN-кода',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              VinScannerWidget(
                onVinScanned: (scannedVin) {
                  _vinController.text = scannedVin;
                  // Вызываем реальный сетевой запрос через Dio!
                  _fetchVehicleSpecs(scannedVin);
                },
              ),
              if (_isLoadingApi) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 24),
              const Text(
                'Данные о машине',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vinController,
                decoration: InputDecoration(
                  labelText: 'VIN-код автомобиля',
                  prefixIcon: const Icon(Icons.pin),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.cloud_download, color: Colors.blueAccent),
                    tooltip: 'Запросить данные по VIN',
                    onPressed: () {
                      if (_vinController.text.isNotEmpty) {
                        _fetchVehicleSpecs(_vinController.text.trim());
                      }
                    },
                  ),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Введите VIN-код' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(labelText: 'Марка (напр. BMW)'),
                      validator: (v) => v == null || v.isEmpty ? 'Заполните' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(labelText: 'Модель (напр. X5)'),
                      validator: (v) => v == null || v.isEmpty ? 'Заполните' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mileageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Текущий пробег (км)'),
                      validator: (v) => v == null || v.isEmpty ? 'Заполните' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Год выпуска'),
                      validator: (v) => v == null || v.isEmpty ? 'Заполните' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveVehicle,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Сохранить автомобиль', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveVehicle() {
    if (_formKey.currentState!.validate()) {
      context.read<VehicleCubit>().addVehicle(
            brand: _brandController.text.trim(),
            model: _modelController.text.trim(),
            mileage: int.tryParse(_mileageController.text) ?? 0,
            vin: _vinController.text.trim(),
            year: int.tryParse(_yearController.text) ?? DateTime.now().year,
          );
      Navigator.pop(context);
    }
  }
}