import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ChangeNotifier that holds the current ThemeMode and persists the choice.
///
/// Web parity: defaults to dark, persists to `shared_preferences` under
/// the `smarthome.theme` key with values `'dark'` / `'light'`.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'smarthome.theme';

  ThemeMode _mode = ThemeMode.dark;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored == 'light') {
        _mode = ThemeMode.light;
      } else {
        _mode = ThemeMode.dark;
      }
    } catch (_) {
      _mode = ThemeMode.dark;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle() async {
    await setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        mode == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }
}
