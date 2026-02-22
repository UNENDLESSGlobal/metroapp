import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';

class BusTrackingScreen extends StatefulWidget {
  final BusRoute route;
  final String destinationStop;

  const BusTrackingScreen({
    super.key,
    required this.route,
    required this.destinationStop,
  });

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  // Tracking
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  int _currentStopIndex = -1; // -1 means haven't started or far from start
  double _distToDest = -1;
  
  // Services
  final BusService _busService = BusService();
  
  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _ringtonePlayer.stop();
  }

  Future<void> _startTracking() async {
    // Permission check
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission required')));
        }
        return;
      }
    }

    setState(() => _isTracking = true);

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null) {
            _updateTracking(position);
        }
      },
      onError: (e) => print('Tracking Error: $e'),
    );
  }

  void _updateTracking(Position position) {
    // 1. Calculate distance to destination
    final destStop = widget.route.stops.firstWhere(
        (s) => s.name.toLowerCase() == widget.destinationStop.toLowerCase(),
        orElse: () => widget.route.stops.last);
    
    double distMeters = Geolocator.distanceBetween(
        position.latitude, position.longitude, destStop.latitude, destStop.longitude);
        
    // 2. Determine "Passed" stops
    // Simple logic: If we are closer to stop i+1 than stop i, we passed stop i.
    // Better logic: find closest stop index. assume we passed all previous indices.
    
    int closestIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < widget.route.stops.length; i++) {
        final stop = widget.route.stops[i];
        double d = Geolocator.distanceBetween(
            position.latitude, position.longitude, stop.latitude, stop.longitude);
        if (d < minDistance) {
            minDistance = d;
            closestIndex = i;
        }
    }

    setState(() {
      _distToDest = distMeters;
      // We assume if closest is index 5, we are "at" or "around" index 5.
      // So passed stops are 0 to 4.
      // To be safer, we can just say "Next Stop" is closest + 1 if we are 'past' closest...
      // For simplicity, let's say Current Stop is closestIndex.
      _currentStopIndex = closestIndex;
    });

    // 3. Check Alarm (1000m ~ 1km)
    if (distMeters < 1000 && distMeters > 0) {
       _triggerAlarm();
    }
  }
  
  bool _alarmTriggered = false;
  final FlutterRingtonePlayer _ringtonePlayer = FlutterRingtonePlayer();
  
  void _triggerAlarm() {
      if (_alarmTriggered) return;
      _alarmTriggered = true;
      
      _ringtonePlayer.playAlarm();
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
            title: const Text('Arriving Soon!'),
            content: Text('You are within 1km of ${widget.destinationStop}'),
            actions: [
                TextButton(
                    onPressed: () {
                        _ringtonePlayer.stop();
                        Navigator.pop(context);
                    }, 
                    child: const Text('Stop Alarm')
                )
            ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.route.routeNo}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
            if (_isTracking) _buildLiveStatus(),
            Expanded(child: _buildTimeline()),
            _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildLiveStatus() {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Destination', style: Theme.of(context).textTheme.bodySmall),
               Text(widget.destinationStop, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
             ],
           ),
           if (_distToDest >= 0)
             Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text('Distance', style: Theme.of(context).textTheme.bodySmall),
                   Text('${(_distToDest/1000).toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                ],
             ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
      return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: widget.route.stops.length,
          itemBuilder: (context, index) {
              final stop = widget.route.stops[index];
              final isPassed = _isTracking && index < _currentStopIndex;
              final isCurrent = _isTracking && index == _currentStopIndex;
              final isDestination = stop.name.toLowerCase() == widget.destinationStop.toLowerCase();
              
              Color dotColor = Colors.grey;
              if (isPassed) dotColor = Colors.grey.shade400;
              if (isCurrent) dotColor = Colors.blue;
              if (isDestination && !isPassed) dotColor = Colors.red;
              
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      Column(
                        children: [
                            Container(
                                width: 16, height: 16,
                                decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                    border: isCurrent ? Border.all(color: Colors.blueAccent.shade100, width: 4) : null
                                ),
                            ),
                            if (index != widget.route.stops.length - 1)
                                Expanded(child: Container(width: 2, color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 30),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        stop.name, 
                                        style: TextStyle(
                                            fontSize: 16, 
                                            fontWeight: isCurrent || isDestination ? FontWeight.bold : FontWeight.normal,
                                            color: isPassed ? Colors.grey : Colors.black
                                        )
                                    ),
                                    if (isDestination) 
                                        const Text('Destination', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    if (isCurrent)
                                        const Text('You are near here', style: TextStyle(color: Colors.blue, fontSize: 12)),
                                ],
                            ),
                          ),
                      )
                  ],
                ),
              );
          },
      );
  }
  
  Widget _buildBottomBar() {
      return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                  onPressed: _isTracking ? _stopTrackingAndReset : _startTracking,
                  icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                  label: Text(_isTracking ? 'Stop Tracking' : 'Start Live Tracking'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? Colors.red : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
              ),
          ),
      );
  }
  
  void _stopTrackingAndReset() {
      _stopTracking();
      setState(() {
          _isTracking = false;
          _currentStopIndex = -1;
          _distToDest = -1;
          _alarmTriggered = false;
      });
  }
}
