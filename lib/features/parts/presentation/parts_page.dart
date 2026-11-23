import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/parts_sources.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/content_list.dart';
import '../../vehicle/domain/models/vehicle.dart';
import '../data/parts_repository.dart';
import '../domain/part.dart';

class PartsPage extends StatefulWidget {
  const PartsPage({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<PartsPage> createState() => _PartsPageState();
}

class _PartsPageState extends State<PartsPage> {
  final _query = TextEditingController();
  late final PartsRepository _repository = context.read<PartsRepository>();
  List<Part> _saved = [];
  List<Part> _results = [];
  String? _submittedQuery;
  bool _loading = true;
  bool _writing = false;
  bool _searching = false;
  String? _searchMessage;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final saved = await _repository.load(widget.vehicle.id);
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search() async {
    if (_searching) return;
    final query = _query.text.trim();
    if (query.isEmpty) {
      setState(() => _searchMessage = 'Введите название детали или артикул.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submittedQuery = query;
      _searching = _repository.hasCatalog;
      _results = [];
      _searchMessage = null;
    });
    if (!_repository.hasCatalog) return;
    try {
      final results = await _repository.search(widget.vehicle, query);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _searchMessage =
              'В каталоге ничего не найдено. Попробуйте поиск по артикулу или откройте один из источников ниже.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _searchMessage =
                  'Каталог сейчас недоступен. Можно посмотреть сохранённые детали или открыть источник в браузере.',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openSource(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // A browser may be missing or disabled.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть браузер.')),
      );
    }
  }

  void _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  List<Part> get _localResults {
    final query = _submittedQuery;
    if (query == null) return [];
    final normalized = normalizePartNumber(query);
    return _saved
        .where(
          (part) =>
              part.name.toLowerCase().contains(query.toLowerCase()) ||
              part.brand.toLowerCase().contains(query.toLowerCase()) ||
              (normalized.isNotEmpty &&
                  (normalizePartNumber(part.number).contains(normalized) ||
                      normalizePartNumber(part.oe).contains(normalized))),
        )
        .toList();
  }

  Future<void> _change(Part part, {bool remove = false}) async {
    setState(() => _writing = true);
    try {
      final saved =
          remove
              ? await _repository.remove(widget.vehicle.id, part)
              : await _repository.save(widget.vehicle.id, part);
      if (mounted) {
        setState(() => _saved = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              remove
                  ? 'Деталь удалена из списка'
                  : 'Деталь сохранена для этого авто',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить список запчастей')),
        );
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _addManually() async {
    final part = await Navigator.of(
      context,
    ).push<Part>(MaterialPageRoute(builder: (_) => const _ManualPartPage()));
    if (mounted && part != null) await _change(part);
  }

  Widget _tile(Part part, {required bool saved}) {
    final alreadySaved = _saved.any((item) => item.key == part.key);
    final verified = part.fitsCatalogVehicle(widget.vehicle.catalogId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              part.name.isEmpty ? part.brand : part.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            SelectableText('${part.brand} · ${part.number}'),
            if (part.oe.isNotEmpty) Text('Оригинальный номер: ${part.oe}'),
            Text(part.source),
            const SizedBox(height: 4),
            Text(
              verified
                  ? 'Совместимость подтверждена каталогом для этой модификации'
                  : part.oe.isNotEmpty && !part.source.startsWith('Добавлено')
                  ? 'Есть связь по артикулу. Проверьте совместимость с вашим авто.'
                  : 'Совместимость не подтверждена',
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _copy(part.number, 'Артикул скопирован'),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Артикул'),
                ),
                TextButton.icon(
                  onPressed:
                      _writing ||
                              _loading ||
                              _loadFailed ||
                              (!saved && alreadySaved)
                          ? null
                          : () => _change(part, remove: saved),
                  icon: Icon(
                    saved
                        ? Icons.bookmark_remove_outlined
                        : Icons.bookmark_add_outlined,
                  ),
                  label: Text(
                    saved
                        ? 'Убрать'
                        : alreadySaved
                        ? 'Сохранено'
                        : 'Сохранить',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Запчасти')),
      body: ContentList(
        children: [
          Text(
            '${widget.vehicle.brand} ${widget.vehicle.model}',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            enabled: !_searching,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Название или артикул',
              hintText: 'Например, масляный фильтр',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.search),
            label: const Text('Найти запчасть'),
          ),
          const SizedBox(height: 8),
          if (widget.vehicle.vin.isNotEmpty)
            TextButton.icon(
              onPressed:
                  () => _copy(
                    widget.vehicle.vin,
                    'VIN скопирован. Его можно вставить в каталог.',
                  ),
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Скопировать VIN для каталога'),
            ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_searchMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(_searchMessage!)),
            ),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Результаты поиска', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final part in _results) _tile(part, saved: false),
          ],
          if (_localResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('В сохранённых деталях', style: theme.textTheme.titleLarge),
            for (final part in _localResults) _tile(part, saved: true),
          ],
          if (_submittedQuery != null) ...[
            const SizedBox(height: 16),
            Text('Проверить в каталоге', style: theme.textTheme.titleLarge),
            const Text(
              'Откроется браузер. При необходимости вставьте VIN на сайте.',
            ),
            for (final source in partsSources(widget.vehicle, _submittedQuery!))
              Card(
                child: ListTile(
                  title: Text(source.name),
                  subtitle: Text(source.detail),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openSource(source.uri),
                ),
              ),
          ],
          const SizedBox(height: 24),
          Text('Сохранённые детали', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed:
                _writing || _loading || _loadFailed ? null : _addManually,
            icon: const Icon(Icons.add),
            label: const Text('Добавить деталь'),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator()
          else if (_loadFailed)
            StatusCard(
              icon: Icons.error_outline,
              title: 'Список недоступен',
              message: 'Не удалось загрузить сохранённые детали.',
              action: TextButton(
                onPressed: _load,
                child: const Text('Повторить'),
              ),
            )
          else if (_saved.isEmpty)
            const Text('Для этого автомобиля пока нет сохранённых деталей.')
          else
            for (final part in _saved) _tile(part, saved: true),
        ],
      ),
    );
  }
}

class _ManualPartPage extends StatefulWidget {
  const _ManualPartPage();

  @override
  State<_ManualPartPage> createState() => _ManualPartPageState();
}

class _ManualPartPageState extends State<_ManualPartPage> {
  final _form = GlobalKey<FormState>();
  String _name = '', _brand = '', _number = '', _oe = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Добавить деталь')),
    body: Form(
      key: _form,
      child: ContentList(
        children: [
          for (final (label, save, requiredField)
              in <(String, void Function(String), bool)>[
                ('Название', (value) => _name = value, false),
                ('Производитель', (value) => _brand = value, true),
                ('Артикул', (value) => _number = value, true),
                ('Оригинальный номер OE', (value) => _oe = value, false),
              ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                maxLength: 100,
                decoration: InputDecoration(labelText: label, counterText: ''),
                validator:
                    (value) =>
                        requiredField && (value ?? '').trim().isEmpty
                            ? 'Заполните поле'
                            : null,
                onSaved: (value) => save((value ?? '').trim()),
              ),
            ),
          FilledButton.icon(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              _form.currentState!.save();
              Navigator.of(context).pop(
                Part(
                  name: _name,
                  brand: _brand,
                  number: _number,
                  oe: _oe,
                  source: 'Добавлено вручную',
                  fitmentConfirmed: false,
                ),
              );
            },
            icon: const Icon(Icons.check),
            label: const Text('Сохранить деталь'),
          ),
        ],
      ),
    ),
  );
}
