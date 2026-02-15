import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../models/transport_mode.dart';
import '../services/trip_history_service.dart';

/// Provider for managing trip history state
class TripProvider extends ChangeNotifier {
  final TripHistoryService _tripHistoryService = TripHistoryService();

  List<Trip> _allTrips = [];
  List<Trip> get allTrips => _allTrips;

  Map<TransportMode, List<Trip>> _tripsByMode = {};
  Map<TransportMode, List<Trip>> get tripsByMode => _tripsByMode;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Load all trips from storage
  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTrips = await _tripHistoryService.getAllTrips();
      
      // Group trips by mode
      _tripsByMode = {};
      for (final mode in TransportMode.values) {
        _tripsByMode[mode] = _allTrips
            .where((t) => t.transportMode == mode)
            .toList();
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load trips: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get last trips for a specific mode
  List<Trip> getLastTripsForMode(TransportMode mode, {int count = 5}) {
    return (_tripsByMode[mode] ?? []).take(count).toList();
  }

  /// Get last trips (all modes)
  List<Trip> getLastTrips({int count = 5}) {
    return _allTrips.take(count).toList();
  }

  /// Check if there are trips for a mode
  bool hasTripsForMode(TransportMode mode) {
    return (_tripsByMode[mode] ?? []).isNotEmpty;
  }

  /// Check if there are any trips
  bool get hasTrips => _allTrips.isNotEmpty;

  /// Add a new trip
  Future<void> addTrip(Trip trip) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _tripHistoryService.addTrip(trip);
      await loadTrips(); // Reload all trips
    } catch (e) {
      _errorMessage = 'Failed to add trip: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _tripHistoryService.deleteTrip(tripId);
      await loadTrips(); // Reload all trips
    } catch (e) {
      _errorMessage = 'Failed to delete trip: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all trip history
  Future<void> clearHistory() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _tripHistoryService.clearHistory();
      _allTrips = [];
      _tripsByMode = {};
    } catch (e) {
      _errorMessage = 'Failed to clear history: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get trip count by mode
  Map<TransportMode, int> get tripCountByMode {
    final counts = <TransportMode, int>{};
    for (final mode in TransportMode.values) {
      counts[mode] = (_tripsByMode[mode] ?? []).length;
    }
    return counts;
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
