import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

bool isGarageKey(String key) =>
    const {
      'vehicles_list_v1',
      'selected_vehicle_id',
      'maintenance_records_v1',
    }.contains(key) ||
    RegExp(
      r'^(maintenance_v2_|maintenance_schedules_|custom_expenses_v1_|saved_parts_v1_)[\w-]+$',
    ).hasMatch(key);

abstract interface class GarageStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<Map<String, String>> snapshot();
  Future<void> replace(Map<String, String> data);
}

class PreferencesGarageStorage implements GarageStorage {
  const PreferencesGarageStorage();

  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async {
    if (!await (await SharedPreferences.getInstance()).setString(key, value)) {
      throw StateError('Storage write failed');
    }
  }

  @override
  Future<Map<String, String>> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, String>{};
    for (final key in prefs.getKeys().where(isGarageKey)) {
      final value = prefs.get(key);
      if (value is String) data[key] = value;
    }
    return data;
  }

  @override
  Future<void> replace(Map<String, String> data) =>
      throw UnsupportedError('Restore requires SQLite');
}

class SqliteGarageStorage implements GarageStorage {
  SqliteGarageStorage({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _path = path;

  static const _table = 'garage_documents';
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _opening;

  Future<Database> get _db async {
    try {
      return await (_opening ??= _open());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final path = _path ?? '${await _factory.getDatabasesPath()}/car_care.db';
    final legacy = await const PreferencesGarageStorage().snapshot();
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE $_table (name TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await _insertAll(db, legacy);
        },
      ),
    );
  }

  Future<void> _insertAll(DatabaseExecutor db, Map<String, String> data) async {
    final batch = db.batch();
    for (final item in data.entries) {
      batch.insert(_table, {'name': item.key, 'value': item.value});
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<String?> read(String key) async {
    final rows = await (await _db).query(
      _table,
      columns: ['value'],
      where: 'name = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.firstOrNull?['value'] as String?;
  }

  @override
  Future<void> write(String key, String value) async {
    await (await _db).insert(_table, {
      'name': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, String>> snapshot() async => {
    for (final row in await (await _db).query(_table))
      row['name'] as String: row['value'] as String,
  };

  @override
  Future<void> replace(Map<String, String> data) async {
    await (await _db).transaction((txn) async {
      await txn.delete(_table);
      await _insertAll(txn, data);
    });
  }
}
