import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

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

/// Service to handle Metro routing and data
class MetroService {
  // Graph: Station -> List of connected stations with weights
  final Map<String, List<_Edge>> _adjacencyList = {};
  
  // All unique stations
  List<String> _stations = [];
  final Map<String, List<double>> _stationCoordinates = {}; // Stores [lat, lon] for each station
  
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<String> getStations() => _stations;
  
  /// Get coordinates for a station
  List<double>? getStationCoordinates(String stationName) => _stationCoordinates[stationName];

  /// Load metro data from CSV files and stitch the graph
  Future<void> loadNetwork() async {
    if (_isLoaded) return;

    try {
      final files = [
        'assets/data/blue_line.csv',
        'assets/data/green_line.csv',
        'assets/data/purple_line.csv',
        'assets/data/orange_line.csv',
        'assets/data/yellow_line.csv',
      ];

      for (final file in files) {
        final String rawCsv = await rootBundle.loadString(file);
        parseCsv(rawCsv);
      }
      
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading metro data: $e');
      rethrow; 
    }
  }

  /// Parse CSV data and build graph
  /// Expected format: Station1,Station2,Line,Time,Fare,Lat1,Lon1,Lat2,Lon2
  void parseCsv(String rawCsv) {
    try {
      final List<List<dynamic>> rows = const CsvToListConverter().convert(rawCsv, eol: '\n');

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 5) continue;

        final String u = row[0].toString().trim();
        final String v = row[1].toString().trim();
        final String line = row[2].toString().trim();
        final int time = int.tryParse(row[3].toString()) ?? 0;
        final double fare = double.tryParse(row[4].toString()) ?? 0.0;

        _addEdge(u, v, line, time, fare);
        _addEdge(v, u, line, time, fare); // Undirected graph
        
        // Extract Coordinates if available
        if (row.length >= 9) {
           final double lat1 = double.tryParse(row[5].toString()) ?? 0.0;
           final double lon1 = double.tryParse(row[6].toString()) ?? 0.0;
           final double lat2 = double.tryParse(row[7].toString()) ?? 0.0;
           final double lon2 = double.tryParse(row[8].toString()) ?? 0.0;
           
           if (lat1 != 0.0 && lon1 != 0.0) _stationCoordinates[u] = [lat1, lon1];
           if (lat2 != 0.0 && lon2 != 0.0) _stationCoordinates[v] = [lat2, lon2];
        }
      }

      _stations = _adjacencyList.keys.toList()..sort();
      _isLoaded = true; // Set flag after successful parsing
    } catch (e) {
      debugPrint('Error parsing CSV: $e');
      rethrow;
    }
  }

  void _addEdge(String u, String v, String line, int time, double fare) {
    if (!_adjacencyList.containsKey(u)) _adjacencyList[u] = [];
    _adjacencyList[u]!.add(_Edge(to: v, line: line, time: time, fare: fare));
  }



  /// Find the shortest path using Dijkstra's algorithm (minimizing time)
  MetroRoute? findRoute(String start, String end) {
    if (!_isLoaded || !_adjacencyList.containsKey(start) || !_adjacencyList.containsKey(end)) {
      return null;
    }

    // Priority Queue: (time, station)
    final SplayTreeMap<int, Set<String>> pq = SplayTreeMap();
    final Map<String, int> dist = {};
    final Map<String, _Edge> previous = {}; // To reconstruct path
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

      if (u == end) break; // Reached destination

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

    if (dist[end] == 999999) return null; // No path found

    // Reconstruct path
    final List<RouteSegment> segments = [];
    String? curr = end;
    
    // We reconstruct backwards, so we collect edges.
    // However, the requested format is a sequence of stations with line info.
    // The "Line" applies to the connection *to* the node.
    
    // Let's build the segment list backwards
    while (curr != start) {
      final String? prev = previousStation[curr];
      final _Edge? edge = previous[curr];
      if (prev == null || edge == null) break;

      segments.insert(0, RouteSegment(
        station: curr!,
        line: edge.line,
        time: edge.time,
        fare: edge.fare,
      ));
      curr = prev;
    }
    
    // Add start station as the first segment (dummy values for line/time/fare or representing start)
    // Actually, usually a route list includes the start point. 
    // Let's modify the requirement to list stations.
    // The first item should be the start station.
    segments.insert(0, RouteSegment(
      station: start,
      line: segments.isNotEmpty ? segments.first.line : 'Start', // Use next line or placeholder
      time: 0,
      fare: 0,
    ));

    return _calculateRouteDetails(segments);
  }

  MetroRoute _calculateRouteDetails(List<RouteSegment> rawSegments) {
    int totalTime = 0;
    double totalFare = 0;
    List<String> interchanges = [];
    String? currentLine;

    // Iterate starting from the first connection (index 1)
    for (int i = 0; i < rawSegments.length; i++) {
        final segment = rawSegments[i];
        
        if (i > 0) {
           totalTime += segment.time;
           totalFare += segment.fare;
        }

        // Logic for interchange:
        // Compare current segment line with previous segment line (if not start)
        // If index is 1 (first actual move), set currentLine.
        // If line changes, add previous station (the transfer point) to interchanges.
        
        if (i == 1) {
            currentLine = segment.line;
        } else if (i > 1) {
            if (segment.line != currentLine) {
                // The station valid *before* this segment was the interchange
                // segments[i-1] is the station node where we are switching *from*
                interchanges.add(rawSegments[i-1].station);
                currentLine = segment.line;
            }
        }
    }

    // Special case for fare calculation: 
    // Metro networks usually calculate fare based on total distance/zones, not sum of edge fares.
    // However, the instructions say "Sum the total FareAmount ... for all segments".
    // I will stick to the instruction.

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
