import 'package:flutter/material.dart';
import '../core/constants/cities.dart';
import '../models/transport_mode.dart';
import '../services/theme_service.dart';

/// Provider for managing app-wide state
class AppStateProvider extends ChangeNotifier {
  final ThemeService _themeService = ThemeService();

  // Selected city
  City _selectedCity = City.mumbai;
  City get selectedCity => _selectedCity;

  // Selected transport mode
  TransportMode _selectedTransportMode = TransportMode.metro;
  TransportMode get selectedTransportMode => _selectedTransportMode;

  // Theme mode
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  // Loading states
  bool _isDetectingLocation = false;
  bool get isDetectingLocation => _isDetectingLocation;

  /// Initialize the provider
  Future<void> init() async {
    _themeMode = await _themeService.getThemeMode();
    notifyListeners();
  }

  /// Set selected city
  void setCity(City city) {
    _selectedCity = city;
    notifyListeners();
  }

  /// Set selected transport mode
  void setTransportMode(TransportMode mode) {
    _selectedTransportMode = mode;
    notifyListeners();
  }

  /// Set location detection loading state
  void setDetectingLocation(bool value) {
    _isDetectingLocation = value;
    notifyListeners();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _themeService.setThemeMode(mode);
    notifyListeners();
  }

  /// Toggle theme
  Future<void> toggleTheme() async {
    _themeMode = await _themeService.toggleTheme();
    notifyListeners();
  }

  /// Check if dark mode is enabled
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Get current map image path based on city and transport mode
  String get currentMapPath {
    return _selectedTransportMode.getMapImagePath(_selectedCity.assetFolderName);
  }

  /// Get current banner image path based on transport mode
  String get currentBannerPath {
    return _selectedTransportMode.bannerImagePath;
  }
}
