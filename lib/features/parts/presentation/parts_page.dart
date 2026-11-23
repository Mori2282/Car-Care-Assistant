import 'package:flutter/material.dart';
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
    final query = _query.text.trim();
    if (normalizePartNumber(query).length < 2 && query.length < 3 ||
        query.length > 80) {
      setState(() => _searchMessage = 'Введите артикул или название детали.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _results = [];
      _searchMessage = null;
    });
    try {
      if (_repository.hasCatalog) {
        final results = await _repository.search(widget.vehicle, query);
        if (!mounted) return;
        setState(() {
          _results = results;
          if (results.isEmpty) {
            _searchMessage =
                'Ничего не найдено. Уточните артикул или попробуйте поиск в интернете.';
          }
        });
      } else {
        final vehicle = widget.vehicle;
        final uri = Uri.https('www.google.com', '/search', {
          'q':
              '$query ${vehicle.brand} ${vehicle.model} ${vehicle.year} ${vehicle.variant} аналог запчасти',
        });
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw StateError('Browser unavailable');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _searchMessage =
                  'Не удалось выполнить поиск. Проверьте подключение и попробуйте снова.',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
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
    return Card(
      child: ListTile(
        title: Text(
          part.name.isEmpty ? '${part.brand} ${part.number}' : part.name,
        ),
        subtitle: Text(
          [
            if (part.name.isNotEmpty) '${part.brand} ${part.number}',
            if (part.oe.isNotEmpty) 'OE: ${part.oe}',
            part.source,
            !saved && part.fitmentConfirmed
                ? 'Совместимость подтверждена каталогом'
                : 'Перед покупкой проверьте совместимость',
          ].join('\n'),
        ),
        trailing: IconButton(
          onPressed:
              _writing || _loading || _loadFailed || (!saved && alreadySaved)
                  ? null
                  : () => _change(part, remove: saved),
          tooltip:
              saved
                  ? 'Убрать из списка'
                  : alreadySaved
                  ? 'Уже сохранено'
                  : 'Сохранить деталь',
          icon: Icon(
            saved
                ? Icons.bookmark_remove_outlined
                : alreadySaved
                ? Icons.bookmark_added
                : Icons.bookmark_add_outlined,
          ),
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
              labelText: 'Номер OE или название детали',
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: const Icon(Icons.search),
            label: Text(
              _repository.hasCatalog
                  ? 'Найти аналоги'
                  : 'Искать аналоги в интернете',
            ),
          ),
          if (!_repository.hasCatalog)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Поиск откроется в браузере. Перед покупкой проверьте совместимость.',
              ),
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
