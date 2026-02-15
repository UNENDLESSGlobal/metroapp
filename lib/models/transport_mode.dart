import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Transport modes available in the app
enum TransportMode {
  metro,
  bus,
  train,
  rickshaw;

  /// Get display name for the transport mode
  String get displayName {
    switch (this) {
      case TransportMode.metro:
        return 'Metro';
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.train:
        return 'Train';
      case TransportMode.rickshaw:
        return 'Auto/Rickshaw';
    }
  }

  /// Get icon for the transport mode
  IconData get icon {
    switch (this) {
      case TransportMode.metro:
        return Icons.subway;
      case TransportMode.bus:
        return Icons.directions_bus;
      case TransportMode.train:
        return Icons.train;
      case TransportMode.rickshaw:
        return Icons.electric_rickshaw;
    }
  }

  /// Get color for the transport mode
  Color get color {
    switch (this) {
      case TransportMode.metro:
        return AppColors.metroColor;
      case TransportMode.bus:
        return AppColors.busColor;
      case TransportMode.train:
        return AppColors.trainColor;
      case TransportMode.rickshaw:
        return AppColors.rickshawColor;
    }
  }

  /// Get banner image path for start button background
  String get bannerImagePath {
    switch (this) {
      case TransportMode.metro:
        return 'assets/images/transport/metro_banner.png';
      case TransportMode.bus:
        return 'assets/images/transport/bus_banner.png';
      case TransportMode.train:
        return 'assets/images/transport/train_banner.png';
      case TransportMode.rickshaw:
        return 'assets/images/transport/rickshaw_banner.png';
    }
  }

  /// Get icon image path for bottom navigation
  String get iconImagePath {
    switch (this) {
      case TransportMode.metro:
        return 'assets/images/transport/metro_icon.png';
      case TransportMode.bus:
        return 'assets/images/transport/bus_icon.png';
      case TransportMode.train:
        return 'assets/images/transport/train_icon.png';
      case TransportMode.rickshaw:
        return 'assets/images/transport/rickshaw_icon.png';
    }
  }

  /// Get map image path for a given city
  String getMapImagePath(String cityFolder) {
    final modeFolder = name; // metro, bus, train, rickshaw
    return 'assets/images/maps/$cityFolder/${modeFolder}_map.png';
  }

  /// Get route screen route name
  String get routeScreenName {
    switch (this) {
      case TransportMode.metro:
        return '/metro-route';
      case TransportMode.bus:
        return '/bus-route';
      case TransportMode.train:
        return '/train-route';
      case TransportMode.rickshaw:
        return '/rickshaw-route';
    }
  }

  /// Parse from string
  static TransportMode fromString(String value) {
    return TransportMode.values.firstWhere(
      (mode) => mode.name == value.toLowerCase(),
      orElse: () => TransportMode.metro,
    );
  }
}
