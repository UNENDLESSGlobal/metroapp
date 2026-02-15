import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trip.dart';
import '../models/transport_mode.dart';

/// Service for handling trip history storage in CSV format
class TripHistoryService {
  static const String _fileName = 'trip_history.csv';
  File? _cachedFile;

  /// Get the trip history file
  Future<File> _getFile() async {
    if (_cachedFile != null) return _cachedFile!;
    
    final directory = await getApplicationDocumentsDirectory();
    _cachedFile = File('${directory.path}/$_fileName');
    return _cachedFile!;
  }

  /// Check if trip history file exists
  Future<bool> hasHistory() async {
    final file = await _getFile();
    if (!await file.exists()) return false;
    
    final content = await file.readAsString();
    final lines = content.trim().split('\n');
    // Has history if more than just the header line
    return lines.length > 1;
  }

  /// Get all trips from history
  Future<List<Trip>> getAllTrips() async {
    try {
      final file = await _getFile();
      
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }

      final rows = const CsvToListConverter().convert(content);
      
      if (rows.isEmpty || rows.length == 1) {
        return []; // Only header or empty
      }

      // Skip header row
      return rows.skip(1).map((row) => Trip.fromCsvRow(row)).toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
    } catch (e) {
      return [];
    }
  }

  /// Get trips filtered by transport mode
  Future<List<Trip>> getTripsByMode(TransportMode mode) async {
    final allTrips = await getAllTrips();
    return allTrips.where((trip) => trip.transportMode == mode).toList();
  }

  /// Get last N trips
  Future<List<Trip>> getLastTrips({int count = 5}) async {
    final allTrips = await getAllTrips();
    return allTrips.take(count).toList();
  }

  /// Get last N trips for a specific transport mode
  Future<List<Trip>> getLastTripsByMode(TransportMode mode, {int count = 5}) async {
    final trips = await getTripsByMode(mode);
    return trips.take(count).toList();
  }

  /// Add a new trip to history
  Future<void> addTrip(Trip trip) async {
    final file = await _getFile();
    
    List<List<dynamic>> rows = [];
    
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.trim().isNotEmpty) {
        rows = const CsvToListConverter().convert(content);
      }
    }

    // Add header if file is empty
    if (rows.isEmpty) {
      rows.add(Trip.csvHeader);
    }

    // Add new trip
    rows.add(trip.toCsvRow());

    // Convert back to CSV and save
    final csv = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csv);
  }

  /// Clear all trip history
  Future<void> clearHistory() async {
    final file = await _getFile();
    
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Delete a specific trip by ID
  Future<void> deleteTrip(String tripId) async {
    final file = await _getFile();
    
    if (!await file.exists()) return;

    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content);

    if (rows.isEmpty) return;

    // Keep header and remove trip with matching ID
    final updatedRows = [
      rows.first, // Header
      ...rows.skip(1).where((row) => row[0].toString() != tripId),
    ];

    final csv = const ListToCsvConverter().convert(updatedRows);
    await file.writeAsString(csv);
  }

  /// Get trip count by transport mode
  Future<Map<TransportMode, int>> getTripCountByMode() async {
    final allTrips = await getAllTrips();
    
    final counts = <TransportMode, int>{};
    for (final mode in TransportMode.values) {
      counts[mode] = allTrips.where((t) => t.transportMode == mode).length;
    }
    
    return counts;
  }
}
