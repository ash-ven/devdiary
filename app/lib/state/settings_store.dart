import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Preferenze del visitatore, salvate nel browser quando possibile.
class SettingsStore extends ChangeNotifier {
  SettingsStore({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  static const themeKey = 'devdiary.theme';
  static const demoNoticeKey = 'devdiary.demoNotice';

  final Future<SharedPreferences> Function() _prefs;

  ThemeMode themeMode = ThemeMode.system;
  bool demoNoticeDismissed = false;

  Future<void> load() async {
    try {
      final p = await _prefs();
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == p.getString(themeKey),
        orElse: () => ThemeMode.system,
      );
      demoNoticeDismissed = p.getBool(demoNoticeKey) ?? false;
    } catch (_) {
      // Archiviazione non disponibile (navigazione privata): valori predefiniti.
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    try {
      await (await _prefs()).setString(themeKey, mode.name);
    } catch (_) {}
  }

  Future<void> dismissDemoNotice() async {
    demoNoticeDismissed = true;
    notifyListeners();
    try {
      await (await _prefs()).setBool(demoNoticeKey, true);
    } catch (_) {}
  }
}
