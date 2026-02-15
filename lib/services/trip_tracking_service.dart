import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'metro_service.dart';
import 'background_service.dart'; // Import the background service file

class TripTrackingService {
  final MetroService _metroService;
  final FlutterBackgroundService _service = FlutterBackgroundService();

  // Custom callback to update UI
  Function(String)? onStatusUpdate;
  Function()? onAlarmTriggered;

  TripTrackingService(this._metroService); // AlarmService is handled in background

  Future<void> init() async {
    await initializeService(); // Initialize the background service
    
    _service.on('update').listen((event) {
      if (event != null && onStatusUpdate != null) {
        final station = event['nextStation'];
        final distance = event['distance'];
        onStatusUpdate!('Next: $station (${distance.toStringAsFixed(1)} km)');
      }
    });

    _service.on('alarmTriggered').listen((event) {
      if (onAlarmTriggered != null) {
        onAlarmTriggered!();
      }
    });
  }

  /// Start tracking for a specific route
  Future<void> startTracking(MetroRoute route) async {
    final targets = _identifyTargets(route);
    
    if (targets.isEmpty) {
        if (onStatusUpdate != null) onStatusUpdate!('No targets to track.');
        return;
    }

    if (await _service.isRunning()) {
      _service.invoke('stopTrip');
    }
    
    await _service.startService();
    
    // Give a small delay for service to start
    await Future.delayed(const Duration(seconds: 1));
    
    _service.invoke('startTrip', {'targets': targets});
    
    if (onStatusUpdate != null) onStatusUpdate!('Tracking Active');
  }

  /// Identify alarms targets: Interchanges and Destination
  /// Returns List of Maps: {station, lat, lon, type}
  List<Map<String, dynamic>> _identifyTargets(MetroRoute route) {
    List<Map<String, dynamic>> targetList = [];
    
    // Add interchanges
    for (final segment in route.segments) {
      if (route.interchangeStations.contains(segment.station) && segment.station != route.segments.last.station) {
         final coords = _metroService.getStationCoordinates(segment.station);
         if (coords != null) {
             targetList.add({
                 'station': segment.station,
                 'lat': coords[0],
                 'lon': coords[1],
                 'type': 'interchange',
             });
         }
      }
    }
    
    // Add destination
    if (route.segments.isNotEmpty) {
      final destSegment = route.segments.last;
      final coords = _metroService.getStationCoordinates(destSegment.station);
       if (coords != null) {
           targetList.add({
               'station': destSegment.station,
               'lat': coords[0],
               'lon': coords[1],
               'type': 'destination',
           });
       }
    }
    
    return targetList;
  }

  Future<void> stopTracking() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopTrip');
    }
    if (onStatusUpdate != null) onStatusUpdate!('Tracking Stopped');
  }
  
  Future<void> stopAlarm() async {
      _service.invoke('stopAlarm');
  }
}
