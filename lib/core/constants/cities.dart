/// Supported cities with their geographic coordinates for auto-detection
enum City {
  mumbai(
    name: 'Mumbai',
    latitude: 19.0760,
    longitude: 72.8777,
  ),
  delhi(
    name: 'Delhi',
    latitude: 28.6139,
    longitude: 77.2090,
  ),
  kolkata(
    name: 'Kolkata',
    latitude: 22.5726,
    longitude: 88.3639,
  ),
  bengaluru(
    name: 'Bengaluru',
    latitude: 12.9716,
    longitude: 77.5946,
  ),
  hyderabad(
    name: 'Hyderabad',
    latitude: 17.3850,
    longitude: 78.4867,
  ),
  chennai(
    name: 'Chennai',
    latitude: 13.0827,
    longitude: 80.2707,
  ),
  ahmedabad(
    name: 'Ahmedabad',
    latitude: 23.0225,
    longitude: 72.5714,
  ),
  pune(
    name: 'Pune',
    latitude: 18.5204,
    longitude: 73.8567,
  );

  final String name;
  final double latitude;
  final double longitude;

  const City({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// Get the folder name for assets
  String get assetFolderName => name.toLowerCase();

  /// Calculate distance from given coordinates (in km)
  double distanceFrom(double lat, double lon) {
    const double earthRadius = 6371; // Earth's radius in km
    
    final double dLat = _toRadians(lat - latitude);
    final double dLon = _toRadians(lon - longitude);
    
    final double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(latitude)) * _cos(_toRadians(lat)) *
        _sin(dLon / 2) * _sin(dLon / 2);
    
    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
  static double _sin(double x) => _taylorSin(x);
  static double _cos(double x) => _taylorCos(x);
  static double _sqrt(double x) => _newtonSqrt(x);
  static double _atan2(double y, double x) => _simpleAtan2(y, x);
  
  // Simple implementations to avoid dart:math import issues
  static double _taylorSin(double x) {
    // Normalize x to [-pi, pi]
    while (x > 3.14159265359) {
      x -= 2 * 3.14159265359;
    }
    while (x < -3.14159265359) {
      x += 2 * 3.14159265359;
    }
    
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }
  
  static double _taylorCos(double x) {
    while (x > 3.14159265359) {
      x -= 2 * 3.14159265359;
    }
    while (x < -3.14159265359) {
      x += 2 * 3.14159265359;
    }
    
    double result = 1;
    double term = 1;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }
  
  static double _newtonSqrt(double x) {
    if (x < 0) return double.nan;
    if (x == 0) return 0;
    
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  
  static double _simpleAtan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 3.14159265359 / 2;
    if (x == 0 && y < 0) return -3.14159265359 / 2;
    return 0;
  }
  
  static double _atan(double x) {
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * (3.14159265359 / 2 - _atan(1 / x.abs()));
    }
    double result = x;
    double term = x;
    for (int i = 1; i < 20; i++) {
      term *= -x * x * (2 * i - 1) / (2 * i + 1);
      result += term / (2 * i + 1);
    }
    return result;
  }

  /// Find the nearest city from given coordinates
  static City findNearest(double latitude, double longitude) {
    City nearest = City.mumbai;
    double minDistance = double.infinity;

    for (final city in City.values) {
      final distance = city.distanceFrom(latitude, longitude);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = city;
      }
    }

    return nearest;
  }

  /// Get all city names as a list
  static List<String> get allCityNames => City.values.map((c) => c.name).toList();
}
