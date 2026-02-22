import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bus_model.dart';
import 'dart:math' show cos, sqrt, asin;

class BusService {
  final Map<String, BusStop> _allStops = {};
  final List<BusRoute> _allRoutes = [];

  // Service status from Supabase
  final Set<String> _disabledStops = {};   // "RouteNo|StopName"
  final Set<String> _disabledRoutes = {};  // "RouteNo"

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  RealtimeChannel? _realtimeChannel;

  /// Load service status from Supabase
  Future<void> _loadServiceStatus() async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('service_status')
          .select()
          .eq('transport_type', 'bus')
          .eq('is_active', false);

      _disabledStops.clear();
      _disabledRoutes.clear();

      for (final row in response as List) {
        final lineName = row['line_name'] as String;
        final stationName = row['station_name'] as String?;
        
        if (stationName == null) {
          _disabledRoutes.add(lineName);
        } else {
          _disabledStops.add('$lineName|$stationName');
        }
      }

      debugPrint('BusService: ${_disabledRoutes.length} routes disabled, ${_disabledStops.length} stops disabled');

      // Subscribe to realtime changes
      _subscribeToChanges();
    } catch (e) {
      debugPrint('BusService: Could not load service status: $e');
    }
  }

  /// Subscribe to realtime changes
  void _subscribeToChanges() {
    _realtimeChannel?.unsubscribe();
    
    final supabase = Supabase.instance.client;
    _realtimeChannel = supabase
        .channel('bus_status')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'transport_type',
            value: 'bus',
          ),
          callback: (payload) {
            debugPrint('BusService: Realtime update received');
            reloadData();
          },
        )
        .subscribe();
  }

  /// Check if a route is disabled
  bool _isRouteActive(String routeNo) {
    return !_disabledRoutes.contains(routeNo);
  }

  /// Check if a stop on a route is active
  bool _isStopActive(String routeNo, String stopName) {
    if (_disabledRoutes.contains(routeNo)) return false;
    if (_disabledStops.contains('$routeNo|$stopName')) return false;
    return true;
  }

  /// Reload data with fresh service status
  Future<void> reloadData() async {
    _allStops.clear();
    _allRoutes.clear();
    _isLoaded = false;
    await loadData();
  }

  /// Loads and parses both CSV files.
  Future<void> loadData() async {
    if (_isLoaded) return;

    try {
      // Load service status first
      await _loadServiceStatus();

      // 1. Load Stops
      final String stopsData = await rootBundle.loadString('assets/data/bus/all_stops.csv');
      List<List<dynamic>> stopsCsv = const CsvToListConverter().convert(stopsData, eol: '\n');

      // Skip header row if exists
      if (stopsCsv.isNotEmpty && stopsCsv[0][0].toString().toLowerCase().contains('stop name')) {
        stopsCsv.removeAt(0);
      }

      for (var row in stopsCsv) {
        if (row.length >= 3) {
          final String name = row[0].toString().trim();
          final double lat = double.tryParse(row[1].toString()) ?? 0.0;
          final double lng = double.tryParse(row[2].toString()) ?? 0.0;
          
          // Store with lowercase key for easy lookup
          _allStops[name.toLowerCase()] = BusStop(name: name, latitude: lat, longitude: lng);
        }
      }

      // 2. Load Routes
      final String routesData = await rootBundle.loadString('assets/data/bus/routes.csv');
      List<List<dynamic>> routesCsv = const CsvToListConverter().convert(routesData, eol: '\n');

      if (routesCsv.isNotEmpty && routesCsv[0][0].toString().toLowerCase().contains('route no')) {
        routesCsv.removeAt(0);
      }

      for (var row in routesCsv) {
        if (row.length >= 3) {
          final String routeNo = row[0].toString().trim();
          final String busType = row[1].toString().trim();
          
          // Skip disabled routes entirely
          if (!_isRouteActive(routeNo)) continue;

          final List<BusStop> routeStops = [];
          
          // Columns 2 to end are stops
          for (int i = 2; i < row.length; i++) {
            final String stopName = row[i].toString().trim();
            if (stopName.isNotEmpty) {
              // Skip disabled stops
              if (!_isStopActive(routeNo, stopName)) continue;

              // Lookup from map, or create dummy if missing
              final BusStop? existingStop = _allStops[stopName.toLowerCase()];
              if (existingStop != null) {
                routeStops.add(existingStop);
              } else {
                routeStops.add(BusStop(name: stopName, latitude: 0.0, longitude: 0.0));
              }
            }
          }

          if (routeStops.isNotEmpty) {
            _allRoutes.add(BusRoute(routeNo: routeNo, busType: busType, stops: routeStops));
          }
        }
      }

      _isLoaded = true;
      debugPrint('BusService: Loaded ${_allStops.length} stops and ${_allRoutes.length} routes.');

    } catch (e) {
      debugPrint('BusService Error: $e');
    }
  }

  /// Returns a list of all known unique stop names for autocomplete.
  List<String> getAllStopNames() {
    return _allStops.values.map((s) => s.name).toList()..sort();
  }
  
  /// Returns a list of all known unique route numbers.
  List<String> getAllRouteNumbers() {
    return _allRoutes.map((r) => r.routeNo).toSet().toList()..sort();
  }
  
  /// Find routes that go from [fromStop] to [toStop].
  List<BusRoute> findRoutes(String fromStop, String toStop) {
    final String from = fromStop.trim().toLowerCase();
    final String to = toStop.trim().toLowerCase();
    
    final List<BusRoute> matchingRoutes = [];

    for (var route in _allRoutes) {
      final int fromIndex = route.stops.indexWhere((s) => s.name.toLowerCase() == from);
      final int toIndex = route.stops.indexWhere((s) => s.name.toLowerCase() == to);

      // Must contain both stops, and 'from' must be before 'to'
      if (fromIndex != -1 && toIndex != -1 && fromIndex < toIndex) {
        matchingRoutes.add(route);
      }
    }

    // Sort by number of stops (fewer stops = "shorter" / better)
    matchingRoutes.sort((a, b) {
      int stopsA = _countStopsBetween(a, from, to);
      int stopsB = _countStopsBetween(b, from, to);
      return stopsA.compareTo(stopsB);
    });

    return matchingRoutes;
  }
  
  int _countStopsBetween(BusRoute route, String from, String to) {
      final int fromIndex = route.stops.indexWhere((s) => s.name.toLowerCase() == from);
      final int toIndex = route.stops.indexWhere((s) => s.name.toLowerCase() == to);
      return (toIndex - fromIndex).abs();
  }
  
  // Calculate distance between two coordinates in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // 2 * R; R = 6371 km
  }

  /// Returns one BusRoute instance for every unique route number.
  List<BusRoute> getAllUniqueRoutes() {
    final Map<String, BusRoute> uniqueRoutes = {};
    for (var route in _allRoutes) {
      if (!uniqueRoutes.containsKey(route.routeNo)) {
        uniqueRoutes[route.routeNo] = route;
      }
    }
    return uniqueRoutes.values.toList()..sort((a, b) => a.routeNo.compareTo(b.routeNo));
  }

  /// Dispose realtime subscription
  void dispose() {
    _realtimeChannel?.unsubscribe();
  }
}
