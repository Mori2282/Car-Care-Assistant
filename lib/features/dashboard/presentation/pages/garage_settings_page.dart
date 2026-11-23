import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/notifications/maintenance_reminders.dart';
import '../../../../core/storage/garage_backup.dart';
import '../../../../core/storage/garage_storage.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/content_list.dart';

class GarageSettingsPage extends StatefulWidget {
  const GarageSettingsPage({super.key});

  @override
  State<GarageSettingsPage> createState() => _GarageSettingsPageState();
}

class _GarageSettingsPageState extends State<GarageSettingsPage> {
  bool _busy = false;
  bool _savingTheme = false;
  String? _message;
  late final _reminders = context.read<MaintenanceReminders>();
  late final _storage = context.read<GarageStorage>();

  Future<void> _selectTheme(ThemeMode mode) async {
    if (_savingTheme) return;
    final cubit = context.read<ThemeCubit>();
    setState(() => _savingTheme = true);
    try {
      await cubit.select(mode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить тему.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  Future<void> _run(Future<String?> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final message = await operation();
      if (mounted) setState(() => _message = message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _message =
                  'Не удалось завершить действие. Проверьте файл или разрешения телефона и попробуйте снова.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _export() async {
    final bytes = Uint8List.fromList(
      utf8.encode(encodeGarageBackup(await _storage.snapshot())),
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Сохранить копию гаража',
      fileName: 'car-care-garage.json',
      bytes: bytes,
    );
    return path == null ? null : 'Копия гаража сохранена.';
  }

  Future<String?> _import() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
      withReadStream: true,
    );
    final file = selection?.files.firstOrNull;
    if (file == null || !mounted) return null;
    if (file.size > maxGarageBackupBytes || file.readStream == null) {
      throw const FormatException('Invalid backup file size');
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in file.readStream!) {
      if (buffer.length + chunk.length > maxGarageBackupBytes) {
        throw const FormatException('Invalid backup file size');
      }
      buffer.add(chunk);
    }
    final documents = decodeGarageBackup(utf8.decode(buffer.takeBytes()));
    if (!mounted) return null;
    final replace = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Заменить текущий гараж?'),
            content: const Text(
              'Все машины, работы, расходы и запчасти будут заменены данными из файла. При необходимости сначала сохраните копию текущего гаража.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Восстановить'),
              ),
            ],
          ),
    );
    if (replace != true) return null;
    await _storage.replace(documents);
    await _reminders.refreshQuietly();
    if (mounted) Navigator.pop(context, true);
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Настройки гаража')),
    body: ContentList(
      children: [
        Text('Тема оформления', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        BlocBuilder<ThemeCubit, ThemeMode>(
          builder:
              (context, mode) => Card(
                child: Column(
                  children: [
                    for (final (option, label) in const [
                      (ThemeMode.system, 'Как на телефоне'),
                      (ThemeMode.light, 'Светлая'),
                      (ThemeMode.dark, 'Тёмная'),
                    ])
                      RadioListTile<ThemeMode>(
                        value: option,
                        groupValue: mode,
                        title: Text(label),
                        onChanged:
                            _savingTheme ? null : (_) => _selectTheme(option),
                      ),
                  ],
                ),
              ),
        ),
        const SizedBox(height: 16),
        Text('Резервная копия', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Сохраните файл перед сменой телефона. В нём будут VIN, история, расходы и детали.',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(_export),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Сохранить копию'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _run(_import),
          icon: const Icon(Icons.upload_outlined),
          label: const Text('Восстановить из файла'),
        ),
        const SizedBox(height: 24),
        Text('Напоминания', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Телефон напомнит о работе по дате. Срок по пробегу обновится, когда вы укажете показание одометра.',
        ),
        const SizedBox(height: 12),
        FutureBuilder<bool>(
          future: _reminders.isEnabled(),
          builder:
              (context, snapshot) => OutlinedButton.icon(
                onPressed:
                    _busy || !snapshot.hasData
                        ? null
                        : () => _run(() async {
                          if (snapshot.data == true) {
                            await _reminders.disable();
                            return 'Напоминания выключены.';
                          }
                          if (!await _reminders.enable()) {
                            return 'Разрешите уведомления в настройках телефона.';
                          }
                          await _reminders.refresh();
                          return 'Напоминания включены.';
                        }),
                icon: const Icon(Icons.notifications_outlined),
                label: Text(
                  snapshot.data == true
                      ? 'Выключить напоминания'
                      : 'Включить напоминания',
                ),
              ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(liveRegion: true, child: Text(_message!)),
          ),
      ],
    ),
  );
}
