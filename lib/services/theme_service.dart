import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling theme persistence
class ThemeService {
  static const String _themeKey = 'theme_mode';
  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get the current theme mode
  Future<ThemeMode> getThemeMode() async {
    await init();
    
    final themeString = _prefs?.getString(_themeKey);
    
    switch (themeString) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light; // Default to light mode
    }
  }

  /// Set the theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    await init();
    
    String themeString;
    switch (mode) {
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }
    
    await _prefs?.setString(_themeKey, themeString);
  }

  /// Toggle between light and dark mode
  Future<ThemeMode> toggleTheme() async {
    final currentMode = await getThemeMode();
    final newMode = currentMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    
    await setThemeMode(newMode);
    return newMode;
  }

  /// Check if dark mode is enabled
  Future<bool> isDarkMode() async {
    final mode = await getThemeMode();
    return mode == ThemeMode.dark;
  }
}
