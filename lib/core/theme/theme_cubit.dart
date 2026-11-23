import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system) {
    _loaded = _restore();
  }

  static const _key = 'appearance_theme_mode';
  late final Future<void> _loaded;

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final name = preferences.getString(_key);
      final mode =
          ThemeMode.values.where((item) => item.name == name).firstOrNull;
      if (mode != null && !isClosed) emit(mode);
    } catch (_) {
      // The system setting remains usable if preferences cannot be read.
    }
  }

  Future<void> select(ThemeMode mode) async {
    await _loaded;
    if (isClosed || state == mode) return;
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(_key, mode.name)) {
      throw StateError('Theme preference could not be saved');
    }
    if (!isClosed) emit(mode);
  }
}
