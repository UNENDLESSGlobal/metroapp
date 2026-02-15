import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

// Entry point for the background service
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Notification setup
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'metro_tracking_channel', // id
    'Metro Tracking', // title
    description: 'Ongoing metro trip tracking', // description
    importance: Importance.low, // Low importance to avoid sound on every update
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Default notification
  await flutterLocalNotificationsPlugin.show(
    888,
    'Metro Trip Tracking',
    'Waiting for trip details...',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'metro_tracking_channel',
        'Metro Tracking',
        icon: 'ic_bg_service_small',
        ongoing: true,
      ),
    ),
  );

  // State
  List<Map<String, dynamic>> targets = [];
  bool isAlarmRinging = false;
  double alarmRadiusKm = 2.5;

  // Listen for data from UI
  service.on('startTrip').listen((event) {
    if (event != null && event['targets'] != null) {
      targets = List<Map<String, dynamic>>.from(event['targets']);
      debugPrint('Background Service: Trip started with ${targets.length} targets');
      
      // Update notification
      if (targets.isNotEmpty) {
          // ignore: deprecated_member_use
        flutterLocalNotificationsPlugin.show(
          888,
          'Metro Trip Tracking',
          'Next Stop: ${targets.first['station']}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'metro_tracking_channel',
              'Metro Tracking',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );
      }
    }
  });

  service.on('stopTrip').listen((event) {
    targets = [];
    service.stopSelf();
  });
  
  service.on('stopAlarm').listen((event) {
    isAlarmRinging = false;
    FlutterRingtonePlayer().stop();
    Vibration.cancel();
  });

  // Location tracking
  const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 50,
  );

  Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
    if (targets.isEmpty) return;

    final target = targets.first;
    final double targetLat = target['lat'];
    final double targetLon = target['lon'];

    final double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      targetLat,
      targetLon,
    );
    
    final double distanceInKm = distanceInMeters / 1000;

    // Update UI about distance
    service.invoke(
      'update',
      {
        'nextStation': target['station'],
        'distance': distanceInKm,
      },
    );

    // Update Notification periodically (optional, maybe too frequent)
    
    // Check for Alarm
    if (distanceInKm <= alarmRadiusKm) {
        // Trigger Alarm
        if (!isAlarmRinging) {
             isAlarmRinging = true;
             
             // Invoke UI to show overlay
             service.invoke('alarmTriggered', {'station': target['station']});
             
             // Play sound/vibrate directly from background
             // Note: Volume control might be limited here as we don't have access to provider settings easily 
             // unless passed in 'startTrip'. Assuming max volume or system default.
             FlutterRingtonePlayer().playAlarm(looping: true, asAlarm: true);
             Vibration.vibrate(pattern: [1000, 1000, 1000, 1000], repeat: 0);

             // High importance notification
               // ignore: deprecated_member_use
             flutterLocalNotificationsPlugin.show(
              889, // Different ID for alarm
              'Arriving at ${target['station']}!',
              'Prepare to exit.',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'metro_alarm_channel',
                  'Metro Alarm',
                  importance: Importance.max,
                  priority: Priority.high,
                  fullScreenIntent: true,
                ),
              ),
            );
        }
        
        // Remove this target if we are very close or logic handled by UI stopping/dismissing
        // For now, we keep ringing until 'stopAlarm' is called by UI.
        // Once stopped, we should remove the target.
    }
  });
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  final AndroidConfiguration androidConfiguration = AndroidConfiguration(
    onStart: onStart,
    autoStart: false,
    isForegroundMode: true,
    notificationChannelId: 'metro_tracking_channel',
    initialNotificationTitle: 'Metro Trip Tracking',
    initialNotificationContent: 'Initializing...',
    foregroundServiceNotificationId: 888,
  );

  final IosConfiguration iosConfiguration = IosConfiguration(
    autoStart: false,
    onForeground: onStart,
    onBackground: onIosBackground,
  );

  await service.configure(
    androidConfiguration: androidConfiguration,
    iosConfiguration: iosConfiguration,
  );
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

