import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/content_list.dart';
import '../../data/datasources/nhtsa_api_service.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vin.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../cubit/vehicle_cubit.dart';
import '../widgets/vin_scanner_widget.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _form = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: widget.vehicle?.brand);
  late final _model = TextEditingController(text: widget.vehicle?.model);
  late final _year = TextEditingController(
    text: widget.vehicle?.year.toString(),
  );
  late final _mileage = TextEditingController(
    text: widget.vehicle?.mileage.toString(),
  );
  late final _vin = TextEditingController(text: widget.vehicle?.vin);
  late final _variant = TextEditingController(text: widget.vehicle?.variant);
  late String _market = widget.vehicle?.market ?? '';
  bool _saving = false;
  bool _lookingUp = false;
  String? _message;
  String? _saveError;
  VehicleMatch? _match;
  bool _frameHelp = false;

  @override
  void dispose() {
    for (final controller in [
      _brand,
      _model,
      _year,
      _mileage,
      _vin,
      _variant,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final value = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const VinScannerPage()));
    if (!mounted || value == null) return;
    _vin.text = value;
    setState(() {
      _match = null;
      _message = null;
      _frameHelp = false;
    });
  }

  Future<void> _lookup() async {
    final vin = normalizeVin(_vin.text);
    final frame = isFrame(vin);
    if (!isVin(vin) && !frame) {
      setState(
        () =>
            _message =
                'Введите 17 символов VIN или номер кузова, например ZVW30-1234567.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _lookingUp = true;
      _frameHelp = false;
      _message = null;
    });
    try {
      final lookup = context.read<VinLookup>();
      final matches = await lookup.find(
        vin,
        market: _market,
        modelYear: int.tryParse(_year.text),
      );
      if (!mounted || normalizeVin(_vin.text) != vin) return;
      if (matches.isEmpty) {
        setState(() {
          _frameHelp = frame;
          _message =
              frame
                  ? (lookup.hasCatalog
                      ? 'Номер кузова не найден. Проверьте его в справочнике или добавьте авто вручную.'
                      : 'Каталог номеров кузова не подключён. Откройте справочник или добавьте авто вручную.')
                  : 'VIN не найден. Сверьте код и заполните данные вручную.';
        });
        return;
      }
      final selected = await showModalBottomSheet<VehicleMatch>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder:
            (context) => FractionallySizedBox(
              heightFactor: 0.72,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Проверьте найденное авто',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final item in matches)
                    Card(
                      child: ListTile(
                        title: Text(
                          item.brand.isEmpty && item.model.isEmpty
                              ? 'Данные производителя'
                              : '${item.brand} ${item.model}'.trim(),
                        ),
                        subtitle: Text(
                          [
                                item.year?.toString(),
                                item.variant,
                                item.source,
                                item.note,
                              ]
                              .whereType<String>()
                              .where((text) => text.isNotEmpty)
                              .join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, item),
                      ),
                    ),
                ],
              ),
            ),
      );
      if (!mounted || selected == null) return;
      if (selected.brand.isNotEmpty) _brand.text = selected.brand;
      if (selected.model.isNotEmpty) _model.text = selected.model;
      if (selected.year != null) _year.text = selected.year.toString();
      if (selected.variant.isNotEmpty) _variant.text = selected.variant;
      setState(() {
        _match = selected;
        _message =
            selected.note.isEmpty
                ? 'Проверьте и дополните данные.'
                : selected.note;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _frameHelp = frame;
          _message = 'Поиск недоступен. Можно заполнить данные вручную.';
        });
      }
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  bool get _matchesCatalog {
    final match = _match;
    return match != null &&
        match.catalogId.isNotEmpty &&
        match.brand == _brand.text.trim() &&
        match.model == _model.text.trim() &&
        (match.year == null || match.year == int.tryParse(_year.text)) &&
        match.variant == _variant.text.trim();
  }

  Future<void> _save() async {
    if (_saving || _lookingUp || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final previous = widget.vehicle;
    final vin = normalizeVin(_vin.text);
    final brand = _brand.text.trim();
    final model = _model.text.trim();
    final year = int.parse(_year.text);
    final variant = _variant.text.trim();
    final identityUnchanged =
        previous != null &&
        previous.vin == vin &&
        previous.brand == brand &&
        previous.model == model &&
        previous.year == year &&
        previous.variant == variant &&
        previous.market == _market;
    try {
      await context.read<VehicleCubit>().saveVehicle(
        Vehicle(
          id: previous?.id ?? '',
          brand: brand,
          model: model,
          mileage: int.parse(_mileage.text),
          vin: vin,
          year: year,
          variant: variant,
          market: _market,
          catalogId:
              _matchesCatalog
                  ? _match!.catalogId
                  : identityUnchanged
                  ? previous.catalogId
                  : '',
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on DuplicateVin {
      if (mounted) {
        setState(
          () =>
              _saveError =
                  'Автомобиль с таким VIN или номером кузова уже есть в гараже.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _saveError =
                  'Не удалось сохранить автомобиль. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      keyboardType: keyboard,
      validator: validator,
      inputFormatters: formatters,
      decoration: InputDecoration(labelText: label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? requiredField(String? value) =>
        value == null || value.trim().isEmpty ? 'Заполните поле' : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.vehicle == null ? 'Добавить авто' : 'Редактировать авто',
        ),
      ),
      body: Form(
        key: _form,
        child: ContentList(
          children: [
            Text('VIN или номер кузова', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Введите VIN или номер кузова (FRAME). Автомобиль можно добавить и вручную.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vin,
              enabled: !_lookingUp && !_saving,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              inputFormatters: [LengthLimitingTextInputFormatter(40)],
              decoration: const InputDecoration(
                labelText: 'VIN или номер кузова',
              ),
              onChanged: (_) {
                if (_message != null || _match != null) {
                  setState(() {
                    _message = null;
                    _match = null;
                    _frameHelp = false;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _lookingUp || _saving ? null : _lookup,
                  icon: const Icon(Icons.search),
                  label: const Text('Найти автомобиль'),
                ),
                OutlinedButton.icon(
                  onPressed: _lookingUp || _saving ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Сканировать'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value:
                  const ['', 'EU', 'US', 'CN', 'JP', 'OTHER'].contains(_market)
                      ? _market
                      : '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Рынок выпуска (если известен)',
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Не знаю')),
                DropdownMenuItem(value: 'EU', child: Text('Европа')),
                DropdownMenuItem(value: 'US', child: Text('Северная Америка')),
                DropdownMenuItem(value: 'CN', child: Text('Китай')),
                DropdownMenuItem(value: 'JP', child: Text('Япония')),
                DropdownMenuItem(value: 'OTHER', child: Text('Другой')),
              ],
              onChanged:
                  _saving || _lookingUp
                      ? null
                      : (value) => setState(() {
                        _market = value ?? '';
                        _match = null;
                        _frameHelp = false;
                        _message = null;
                      }),
            ),
            if (_lookingUp)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(liveRegion: true, child: Text(_message!)),
              ),
            if (_frameHelp)
              OutlinedButton.icon(
                onPressed: () async {
                  final frame = normalizeVin(_vin.text);
                  await Clipboard.setData(ClipboardData(text: frame));
                  var opened = false;
                  try {
                    opened = await launchUrl(
                      Uri.https('partsouq.com', '/en/catalogs/'),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {
                    // The number remains on the clipboard when no browser is installed.
                  }
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Номер кузова скопирован. Браузер не открылся.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Скопировать номер и открыть справочник'),
              ),
            const SizedBox(height: 24),
            Text('Данные автомобиля', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _field(_brand, 'Марка', validator: requiredField),
            _field(_model, 'Модель', validator: requiredField),
            _field(
              _year,
              'Год',
              keyboard: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (value) {
                final year = int.tryParse(value ?? '');
                return year == null ||
                        year < 1886 ||
                        year > DateTime.now().year + 1
                    ? 'Введите корректный год'
                    : null;
              },
            ),
            _field(
              _mileage,
              'Пробег, км',
              keyboard: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator:
                  (value) =>
                      int.tryParse(value ?? '') == null
                          ? 'Введите пробег'
                          : null,
            ),
            _field(_variant, 'Двигатель или модификация (если известны)'),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _saveError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: _saving || _lookingUp ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Сохраняем…' : 'Сохранить автомобиль'),
            ),
          ],
        ),
      ),
    );
  }
}
