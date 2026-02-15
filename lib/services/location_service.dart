import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/constants/cities.dart';

/// Service for handling location detection
class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check and request location permission
  Future<LocationPermission> checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      final permission = await checkAndRequestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get city name from coordinates
  Future<String?> getCityFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Try locality (city) first, then subAdministrativeArea
        return placemark.locality ?? placemark.subAdministrativeArea;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Detect the nearest supported city based on current location
  Future<City?> detectNearestCity() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        return null;
      }

      // Find the nearest supported city
      return City.findNearest(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }

  /// Auto-detect city with fallback to reverse geocoding
  Future<City?> autoDetectCity() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) {
        return null;
      }

      // First try to get the city name from coordinates
      final cityName = await getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (cityName != null) {
        // Try to match with supported cities
        for (final city in City.values) {
          if (cityName.toLowerCase().contains(city.name.toLowerCase()) ||
              city.name.toLowerCase().contains(cityName.toLowerCase())) {
            return city;
          }
        }
      }

      // Fallback to nearest city by coordinates
      return City.findNearest(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }
}
