import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Google Apps Script Web App API URL
const String _kApiUrl =
    'https://script.google.com/macros/s/AKfycbzVaIluUiAlEzmiNrQSHewk7fB9owJF7Mgor_pjziECWyiw7xpOX2wQfY1xlDre0GfY/exec';

/// SharedPreferences key for cached JSON
const String _kCacheKey = 'metro_routes_cache';

/// Represents a segment of the metro route
class RouteSegment {
  final String station;
  final String line;
  final int time;
  final double fare;

  RouteSegment({
    required this.station,
    required this.line,
    required this.time,
    required this.fare,
  });

  Map<String, dynamic> toJson() => {
    'station': station,
    'line': line,
    'time': time,
    'fare': fare,
  };

  factory RouteSegment.fromJson(Map<String, dynamic> json) => RouteSegment(
    station: json['station'] as String,
    line: json['line'] as String,
    time: json['time'] as int,
    fare: (json['fare'] as num).toDouble(),
  );
}

/// Represents the final calculated route
class MetroRoute {
  final List<RouteSegment> segments;
  final int totalTime;
  final double totalFare;
  final List<String> interchangeStations;

  MetroRoute({
    required this.segments,
    required this.totalTime,
    required this.totalFare,
    required this.interchangeStations,
  });
}

/// Service to handle Metro routing and data via Google Sheets API
class MetroService {
  // Graph: Station -> List of connected stations with weights
  final Map<String, List<_Edge>> _adjacencyList = {};

  // All unique stations (including disabled ones)
  List<String> _stations = [];
  final Map<String, List<double>> _stationCoordinates = {};

  // Stations that exist in the data but have NO operational connections
  Set<String> _disabledStations = {};

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<String> getStations() => _stations;

  /// Set of station names that have no operational connections.
  Set<String> get disabledStations => _disabledStations;

  /// Returns true if the station exists only on non-operational edges.
  bool isStationDisabled(String stationName) =>
      _disabledStations.contains(stationName);

  /// Get coordinates for a station
  List<double>? getStationCoordinates(String stationName) =>
      _stationCoordinates[stationName];

  // ─────────── Sync / Data Loading ───────────

  /// Main entry point: sync metro data from API or cache.
  /// Call this on app startup.
  Future<void> syncMetroData() async {
    if (_isLoaded) return;

    try {
      final isOnline = await _checkConnectivity();

      if (isOnline) {
        await _fetchFromApi();
      } else {
        await _loadFromCache();
      }
    } catch (e) {
      debugPrint('MetroService.syncMetroData error: $e');
      // Try cache as last resort
      if (!_isLoaded) {
        try {
          await _loadFromCache();
        } catch (cacheError) {
          debugPrint('MetroService: Cache fallback also failed: $cacheError');
        }
      }
    }
  }

  /// Check if the device has network connectivity.
  Future<bool> _checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Fetch route data from the Google Sheets API via HTTP GET.
  Future<void> _fetchFromApi() async {
    debugPrint('MetroService: Fetching data from API…');

    final response = await http.get(Uri.parse(_kApiUrl)).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode != 200) {
      throw Exception('API returned HTTP ${response.statusCode}');
    }

    final String jsonString = response.body;
    final List<dynamic> data = json.decode(jsonString) as List<dynamic>;

    // Parse and build graph
    _buildGraphFromJson(data);

    // Cache the raw JSON for offline use
    await _saveToCache(jsonString);

    debugPrint('MetroService: Loaded ${_stations.length} stations from API');
  }

  /// Load cached JSON data from SharedPreferences.
  Future<void> _loadFromCache() async {
    debugPrint('MetroService: Loading data from cache…');

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kCacheKey);

    if (cached == null || cached.isEmpty) {
      debugPrint('MetroService: No cached data available');
      return;
    }

    final List<dynamic> data = json.decode(cached) as List<dynamic>;
    _buildGraphFromJson(data);

    debugPrint('MetroService: Loaded ${_stations.length} stations from cache');
  }

  /// Save raw JSON string to SharedPreferences.
  Future<void> _saveToCache(String jsonString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCacheKey, jsonString);
  }

  // ─────────── Graph Building ───────────

  /// Build the adjacency-list graph from parsed JSON data.
  /// Each entry represents an edge between two stations.
  /// 
  /// Expected JSON fields:
  /// Station1, Station2, Line, Time, Fare, Lat1, Lon1, Lat2, Lon2, Is_Operational
  void _buildGraphFromJson(List<dynamic> data) {
    _adjacencyList.clear();
    _stations.clear();
    _stationCoordinates.clear();
    _disabledStations.clear();
    _isLoaded = false;

    // First pass: collect ALL station names from every row (operational or not)
    final Set<String> allStationNames = {};

    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;

      final String u = (item['Station1'] ?? item['station1'] ?? '').toString().trim();
      final String v = (item['Station2'] ?? item['station2'] ?? '').toString().trim();
      final String line = (item['Line'] ?? item['line'] ?? '').toString().trim();
      final int time = _parseInt(item['Time'] ?? item['time']);
      final double fare = _parseDouble(item['Fare'] ?? item['fare']);

      if (u.isEmpty || v.isEmpty) continue;

      // Track every station name regardless of operational status
      allStationNames.add(u);
      allStationNames.add(v);

      // Parse coordinates
      final double lat1 = _parseDouble(item['Lat1'] ?? item['lat1']);
      final double lon1 = _parseDouble(item['Lon1'] ?? item['lon1']);
      final double lat2 = _parseDouble(item['Lat2'] ?? item['lat2']);
      final double lon2 = _parseDouble(item['Lon2'] ?? item['lon2']);

      if (lat1 != 0.0 && lon1 != 0.0) _stationCoordinates[u] = [lat1, lon1];
      if (lat2 != 0.0 && lon2 != 0.0) _stationCoordinates[v] = [lat2, lon2];

      // Check Is_Operational flag — skip edge if not operational
      final isOperational = _parseBool(
        item['Is_Operational'] ?? item['is_operational'] ?? item['IsOperational'] ?? true,
      );

      if (!isOperational) continue;

      _addEdge(u, v, line, time, fare);
      _addEdge(v, u, line, time, fare); // Undirected graph
    }

    // Disabled stations = stations that appear in data but have zero operational edges
    _disabledStations = allStationNames.difference(_adjacencyList.keys.toSet());

    // Include ALL stations (operational + disabled) in the sorted list
    _stations = allStationNames.toList()..sort();
    _isLoaded = true;
  }

  /// Parse JSON data from a list of maps (for testing without network).
  /// This is the public API for tests.
  void parseJsonData(List<Map<String, dynamic>> data) {
    _buildGraphFromJson(data);
  }

  // ─────────── Helpers ───────────

  int _parseInt(dynamic val) {
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  double _parseDouble(dynamic val) {
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  bool _parseBool(dynamic val) {
    if (val is bool) return val;
    if (val is String) {
      final lower = val.toLowerCase().trim();
      return lower == 'true' || lower == 'yes' || lower == '1';
    }
    if (val is num) return val != 0;
    return true;
  }

  void _addEdge(String u, String v, String line, int time, double fare) {
    if (!_adjacencyList.containsKey(u)) _adjacencyList[u] = [];
    _adjacencyList[u]!.add(_Edge(to: v, line: line, time: time, fare: fare));
  }

  // ─────────── Pathfinding (Dijkstra) ───────────

  /// Reload the network (re-sync from API or cache).
  Future<void> reloadNetwork() async {
    _adjacencyList.clear();
    _stations.clear();
    _stationCoordinates.clear();
    _isLoaded = false;
    await syncMetroData();
  }

  /// Legacy alias — calls syncMetroData().
  Future<void> loadNetwork() async {
    await syncMetroData();
  }

  /// Find the shortest path using Dijkstra's algorithm (minimizing time).
  MetroRoute? findRoute(String start, String end) {
    if (!_isLoaded ||
        !_adjacencyList.containsKey(start) ||
        !_adjacencyList.containsKey(end)) {
      return null;
    }

    // Priority Queue: (time, station)
    final SplayTreeMap<int, Set<String>> pq = SplayTreeMap();
    final Map<String, int> dist = {};
    final Map<String, _Edge> previous = {};
    final Map<String, String> previousStation = {};

    // Initialize distances
    for (final station in _stations) {
      dist[station] = 999999; // Infinity
    }

    dist[start] = 0;
    _addToPQ(pq, 0, start);

    while (pq.isNotEmpty) {
      final int currentDist = pq.firstKey()!;
      final Set<String> currentStations = pq[currentDist]!;
      final String u = currentStations.first;

      currentStations.remove(u);
      if (currentStations.isEmpty) pq.remove(currentDist);

      if (u == end) break;

      if (currentDist > dist[u]!) continue;

      final neighbors = _adjacencyList[u];
      if (neighbors == null) continue;

      for (final edge in neighbors) {
        final int newDist = currentDist + edge.time;

        if (newDist < dist[edge.to]!) {
          dist[edge.to] = newDist;
          previous[edge.to] = edge;
          previousStation[edge.to] = u;
          _addToPQ(pq, newDist, edge.to);
        }
      }
    }

    if (dist[end] == 999999) return null;

    // Reconstruct path
    final List<RouteSegment> segments = [];
    String? curr = end;

    while (curr != start) {
      final String? prev = previousStation[curr];
      final _Edge? edge = previous[curr];
      if (prev == null || edge == null) break;

      segments.insert(
        0,
        RouteSegment(
          station: curr!,
          line: edge.line,
          time: edge.time,
          fare: edge.fare,
        ),
      );
      curr = prev;
    }

    segments.insert(
      0,
      RouteSegment(
        station: start,
        line: segments.isNotEmpty ? segments.first.line : 'Start',
        time: 0,
        fare: 0,
      ),
    );

    return _calculateRouteDetails(segments);
  }

  MetroRoute _calculateRouteDetails(List<RouteSegment> rawSegments) {
    int totalTime = 0;
    double totalFare = 0;
    List<String> interchanges = [];
    String? currentLine;

    for (int i = 0; i < rawSegments.length; i++) {
      final segment = rawSegments[i];

      if (i > 0) {
        totalTime += segment.time;
        totalFare += segment.fare;
      }

      if (i == 1) {
        currentLine = segment.line;
      } else if (i > 1) {
        if (segment.line != currentLine) {
          interchanges.add(rawSegments[i - 1].station);
          currentLine = segment.line;
        }
      }
    }

    return MetroRoute(
      segments: rawSegments,
      totalTime: totalTime,
      totalFare: totalFare,
      interchangeStations: interchanges,
    );
  }

  void _addToPQ(SplayTreeMap<int, Set<String>> pq, int dist, String node) {
    if (!pq.containsKey(dist)) pq[dist] = <String>{};
    pq[dist]!.add(node);
  }
}

class _Edge {
  final String to;
  final String line;
  final int time;
  final double fare;

  _Edge({
    required this.to,
    required this.line,
    required this.time,
    required this.fare,
  });
}
