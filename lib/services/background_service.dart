import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

// ─────────── Background isolate entry point ───────────

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // ── Notification setup ──
  final notifPlugin = FlutterLocalNotificationsPlugin();

  const trackingChannel = AndroidNotificationChannel(
    'metro_tracking_channel',
    'Metro Tracking',
    description: 'Ongoing metro trip tracking',
    importance: Importance.low,
  );

  const alarmChannel = AndroidNotificationChannel(
    'metro_alarm_channel',
    'Metro Alarm',
    description: 'Destination arrival alarm',
    importance: Importance.max,
  );

  final androidImpl =
      notifPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(trackingChannel);
  await androidImpl?.createNotificationChannel(alarmChannel);

  await notifPlugin.show(
    888,
    'Metro Trip Tracking',
    'Waiting for trip details…',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'metro_tracking_channel',
        'Metro Tracking',
        icon: 'ic_bg_service_small',
        ongoing: true,
      ),
    ),
  );

  // ── Hybrid tracking state ──
  Timer? hybridTimer;
  int elapsedSeconds = 0;
  int totalRouteTimeMins = 0;
  double destLat = 0;
  double destLon = 0;
  String destStation = '';
  int thresholdMins = 3;
  bool soundEnabled = true;
  bool vibrateEnabled = true;
  double volume = 0.8;
  bool alarmFired = false;

  // ── Start hybrid trip ──
  service.on('startHybridTrip').listen((event) {
    if (event == null) return;

    totalRouteTimeMins = (event['totalRouteTimeMins'] as num?)?.toInt() ?? 0;
    destLat = (event['destLat'] as num?)?.toDouble() ?? 0;
    destLon = (event['destLon'] as num?)?.toDouble() ?? 0;
    destStation = (event['destStation'] as String?) ?? '';
    thresholdMins = (event['thresholdMins'] as num?)?.toInt() ?? 3;
    soundEnabled = (event['soundEnabled'] as bool?) ?? true;
    vibrateEnabled = (event['vibrateEnabled'] as bool?) ?? true;
    volume = (event['volume'] as num?)?.toDouble() ?? 0.8;
    elapsedSeconds = 0;
    alarmFired = false;

    debugPrint(
        'BG: Hybrid trip started → $destStation, total ${totalRouteTimeMins}m');

    // Update notification
    notifPlugin.show(
      888,
      'Metro Tracking Active',
      'ETA: ~$totalRouteTimeMins mins to $destStation',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'metro_tracking_channel',
          'Metro Tracking',
          icon: 'ic_bg_service_small',
          ongoing: true,
        ),
      ),
    );

    // Cancel any previous timer
    hybridTimer?.cancel();

    // ── 10-second hybrid evaluation loop ──
    hybridTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      elapsedSeconds += 10;
      double remainingMins;
      bool gpsActive = false;

      // ── Primary check: GPS ──
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );

        final distMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destLat,
          destLon,
        );
        final distKm = distMeters / 1000.0;

        // Convert distance to time at average metro speed (35 km/h)
        const double metroSpeedKmPerMin = 35.0 / 60.0; // ~0.583 km/min
        remainingMins = distKm / metroSpeedKmPerMin;
        gpsActive = true;

        // Sync the stopwatch to match physical reality
        final newElapsed =
            ((totalRouteTimeMins - remainingMins) * 60).round().clamp(0, totalRouteTimeMins * 60);
        elapsedSeconds = newElapsed;

        debugPrint(
            'BG: GPS active → ${distKm.toStringAsFixed(1)}km, ETA: ${remainingMins.toStringAsFixed(1)}m');
      } catch (_) {
        // ── Fallback: timer math ──
        final elapsedMins = elapsedSeconds / 60.0;
        remainingMins = totalRouteTimeMins - elapsedMins;
        gpsActive = false;

        debugPrint(
            'BG: GPS lost → timer fallback, ETA: ${remainingMins.toStringAsFixed(1)}m');
      }

      // Clamp to zero
      if (remainingMins < 0) remainingMins = 0;

      // ── Send ETA update to UI ──
      service.invoke('etaUpdate', {
        'remainingMins': remainingMins,
        'gpsActive': gpsActive,
        'destStation': destStation,
      });

      // ── Update persistent notification ──
      final etaText = remainingMins < 1
          ? 'Arriving now!'
          : 'ETA: ~${remainingMins.round()} mins to $destStation';
      notifPlugin.show(
        888,
        'Metro Tracking Active',
        etaText + (gpsActive ? ' (GPS)' : ' (Timer)'),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'metro_tracking_channel',
            'Metro Tracking',
            icon: 'ic_bg_service_small',
            ongoing: true,
          ),
        ),
      );

      // ── Trigger condition ──
      if (remainingMins <= thresholdMins && !alarmFired) {
        alarmFired = true;
        debugPrint('BG: ⏰ ALARM TRIGGERED! ETA: ${remainingMins.toStringAsFixed(1)}m');

        // Play alarm sound
        if (soundEnabled) {
          await FlutterRingtonePlayer().playAlarm(
            looping: true,
            volume: volume,
            asAlarm: true,
          );
        }

        // Vibrate
        if (vibrateEnabled) {
          if (await Vibration.hasVibrator() == true) {
            Vibration.vibrate(
                pattern: [1000, 1000, 1000, 1000], repeat: 0);
          }
        }

        // High-priority notification (pops over lock screen)
        notifPlugin.show(
          889,
          '🔔 Arriving at $destStation!',
          'Get ready! ~${remainingMins.round()} mins remaining.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'metro_alarm_channel',
              'Metro Alarm',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              playSound: true,
            ),
          ),
        );

        // Notify UI to show overlay
        service.invoke('alarmTriggered', {
          'destStation': destStation,
          'remainingMins': remainingMins,
        });
      }
    });
  });

  // ── Stop hybrid trip ──
  service.on('stopHybridTrip').listen((event) {
    hybridTimer?.cancel();
    hybridTimer = null;
    elapsedSeconds = 0;
    alarmFired = false;
    FlutterRingtonePlayer().stop();
    Vibration.cancel();

    // Dismiss notifications
    notifPlugin.cancel(888);
    notifPlugin.cancel(889);

    service.stopSelf();
    debugPrint('BG: Hybrid trip stopped');
  });

  // ── Stop alarm only (keep tracking) ──
  service.on('stopAlarm').listen((event) {
    alarmFired = true; // Prevent re-trigger
    FlutterRingtonePlayer().stop();
    Vibration.cancel();
    notifPlugin.cancel(889);
    debugPrint('BG: Alarm stopped');
  });
}

// ─────────── Service initializer ───────────

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  final androidConfig = AndroidConfiguration(
    onStart: onStart,
    autoStart: false,
    isForegroundMode: true,
    notificationChannelId: 'metro_tracking_channel',
    initialNotificationTitle: 'Metro Trip Tracking',
    initialNotificationContent: 'Initializing…',
    foregroundServiceNotificationId: 888,
  );

  final iosConfig = IosConfiguration(
    autoStart: false,
    onForeground: onStart,
    onBackground: onIosBackground,
  );

  await service.configure(
    androidConfiguration: androidConfig,
    iosConfiguration: iosConfig,
  );
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}
