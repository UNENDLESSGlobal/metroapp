import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'background_service.dart';

/// UI-facing wrapper around the background service for hybrid tracking.
///
/// Call [init] once, then [startTracking] with route data.
/// Listen to [onEtaUpdate] and [onAlarmTriggered] callbacks for UI updates.
class HybridTrackingService {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Called every ~10s with remaining minutes and GPS status.
  void Function(double remainingMins, bool gpsActive, String destStation)?
      onEtaUpdate;

  /// Called when the alarm fires.
  void Function(String destStation, double remainingMins)? onAlarmTriggered;

  /// Initialize the background service and wire up listeners.
  Future<void> init() async {
    try {
      await initializeService();
    } catch (e) {
      debugPrint('HybridTrackingService: init error: $e');
    }

    _service.on('etaUpdate').listen((event) {
      if (event == null || onEtaUpdate == null) return;
      final remaining = (event['remainingMins'] as num?)?.toDouble() ?? 0;
      final gps = (event['gpsActive'] as bool?) ?? false;
      final dest = (event['destStation'] as String?) ?? '';
      onEtaUpdate!(remaining, gps, dest);
    });

    _service.on('alarmTriggered').listen((event) {
      if (event == null || onAlarmTriggered == null) return;
      final dest = (event['destStation'] as String?) ?? '';
      final remaining = (event['remainingMins'] as num?)?.toDouble() ?? 0;
      onAlarmTriggered!(dest, remaining);
    });
  }

  /// Start hybrid tracking.
  ///
  /// [totalRouteTimeMins] — the total estimated route time from the search.
  /// [destLat], [destLon] — lat/lon of the destination station.
  /// [destStation] — human-readable destination name.
  /// [thresholdMins] — how many minutes before arrival to trigger the alarm.
  /// [soundEnabled], [vibrateEnabled], [volume] — alarm settings.
  Future<void> startTracking({
    required int totalRouteTimeMins,
    required double destLat,
    required double destLon,
    required String destStation,
    required int thresholdMins,
    required bool soundEnabled,
    required bool vibrateEnabled,
    required double volume,
  }) async {
    // Ensure the service is running
    if (await _service.isRunning()) {
      _service.invoke('stopHybridTrip');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    await _service.startService();
    // Give the isolate a moment to boot
    await Future.delayed(const Duration(seconds: 1));

    _service.invoke('startHybridTrip', {
      'totalRouteTimeMins': totalRouteTimeMins,
      'destLat': destLat,
      'destLon': destLon,
      'destStation': destStation,
      'thresholdMins': thresholdMins,
      'soundEnabled': soundEnabled,
      'vibrateEnabled': vibrateEnabled,
      'volume': volume,
    });

    debugPrint(
        'HybridTrackingService: sent startHybridTrip → $destStation, ${totalRouteTimeMins}m');
  }

  /// Stop tracking + alarm + service.
  Future<void> stopTracking() async {
    final running = await _service.isRunning();
    if (running) {
      _service.invoke('stopHybridTrip');
    }
    debugPrint('HybridTrackingService: stopped');
  }

  /// Stop the alarm but keep tracking running.
  Future<void> stopAlarm() async {
    _service.invoke('stopAlarm');
    debugPrint('HybridTrackingService: alarm stopped');
  }
}
