import 'package:flutter/material.dart';
import '../../../../data/services/local_storage_service.dart';

/// Controller responsible for managing and persisting the application's [ThemeMode].
class ThemeController extends ChangeNotifier {
  ThemeController({LocalStorageService? localStorageService})
      : _storageService = localStorageService ?? LocalStorageService();

  static final ThemeController instance = ThemeController();

  final LocalStorageService _storageService;
  ThemeMode _themeMode = ThemeMode.system;

  /// The current active [ThemeMode].
  ThemeMode get themeMode => _themeMode;

  /// Determines whether the effective theme brightness is dark.
  bool isDark(BuildContext context) {
    return switch (_themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => Theme.of(context).brightness == Brightness.dark,
    };
  }

  /// Loads the persisted theme mode from local storage.
  Future<void> loadThemeMode() async {
    final savedMode = await _storageService.getThemeMode();
    if (savedMode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedMode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedMode == 'system') {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Sets the [ThemeMode] and persists the preference.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final modeString = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    };
    await _storageService.setThemeMode(modeString);
  }

  /// Toggles between light and dark mode.
  ///
  /// If currently in dark mode, switches to light mode.
  /// If currently in light mode (or system resolves to light), switches to dark mode.
  Future<void> toggleTheme([BuildContext? context]) async {
    final bool currentIsDark;
    if (_themeMode == ThemeMode.dark) {
      currentIsDark = true;
    } else if (_themeMode == ThemeMode.light) {
      currentIsDark = false;
    } else if (context != null) {
      currentIsDark = Theme.of(context).brightness == Brightness.dark;
    } else {
      currentIsDark = false;
    }

    final newMode = currentIsDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Resets the controller state (useful for tests).
  @visibleForTesting
  void reset([ThemeMode mode = ThemeMode.system]) {
    _themeMode = mode;
    notifyListeners();
  }
}
