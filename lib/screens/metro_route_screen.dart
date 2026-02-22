import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transport_mode.dart';
import '../models/trip.dart';
import '../providers/app_state_provider.dart';
import '../providers/alarm_settings_provider.dart';
import '../providers/trip_provider.dart';
import '../core/constants/app_colors.dart';
import '../services/metro_service.dart';
import '../services/hybrid_tracking_service.dart';


/// Metro route selection screen
class MetroRouteScreen extends StatefulWidget {
  const MetroRouteScreen({super.key});

  @override
  State<MetroRouteScreen> createState() => _MetroRouteScreenState();
}

class _MetroRouteScreenState extends State<MetroRouteScreen> {
  final MetroService _metroService = MetroService();
  
  String? _startStation;
  String? _endStation;
  bool _isLoading = false;
  List<String> _stations = [];
  MetroRoute? _calculatedRoute;
  List<Map<String, dynamic>> _blockedStations = [];
  
  // Tracking State
  HybridTrackingService? _trackingService;
  bool _isTracking = false;
  double _etaMinutes = 0;
  bool _gpsActive = false;
  bool _isAlarmRinging = false;
  String _alarmDestStation = '';
  double _alarmRemainingMins = 0;
  int _totalRouteTime = 0;
  String _destStationName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStations();
      _initTracking();
    });
  }

  void _initTracking() async {
    try {
      _trackingService = HybridTrackingService();
      await _trackingService?.init();

      _trackingService?.onEtaUpdate = (remaining, gps, dest) {
        if (mounted) {
          setState(() {
            _etaMinutes = remaining;
            _gpsActive = gps;
          });
        }
      };

      _trackingService?.onAlarmTriggered = (dest, remaining) {
        if (mounted) {
          setState(() {
            _isAlarmRinging = true;
            _alarmDestStation = dest;
            _alarmRemainingMins = remaining;
          });
        }
      };
    } catch (e) {
      debugPrint('Error initializing tracking: $e');
    }
  }

  @override
  void dispose() {
    _trackingService?.stopTracking();
    super.dispose();
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      HapticFeedback.heavyImpact();
      await _trackingService?.stopTracking();
      if (mounted) {
        setState(() {
          _isTracking = false;
          _etaMinutes = 0;
          _gpsActive = false;
          _isAlarmRinging = false;
        });
      }
    } else {
      HapticFeedback.mediumImpact();
      if (_calculatedRoute == null) return;

      // Get destination coordinates
      final destSegment = _calculatedRoute!.segments.last;
      final destCoords = _metroService.getStationCoordinates(destSegment.station);
      if (destCoords == null || destCoords.length < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No GPS coordinates for destination'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Read alarm settings
      final alarmSettings = context.read<AlarmSettingsProvider>();

      await _trackingService?.startTracking(
        totalRouteTimeMins: _calculatedRoute!.totalTime,
        destLat: destCoords[0],
        destLon: destCoords[1],
        destStation: destSegment.station,
        thresholdMins: alarmSettings.alarmThresholdMinutes,
        soundEnabled: alarmSettings.isSoundEnabled,
        vibrateEnabled: alarmSettings.isVibrateEnabled,
        volume: alarmSettings.volume,
      );

      if (mounted) {
        setState(() {
          _isTracking = true;
          _totalRouteTime = _calculatedRoute!.totalTime;
          _destStationName = destSegment.station;
          _etaMinutes = _totalRouteTime.toDouble();
        });
      }
    }
  }

  Future<void> _stopAlarm() async {
    await _trackingService?.stopAlarm();
    if (mounted) {
      setState(() => _isAlarmRinging = false);
    }
  }

  Future<void> _stopAlarmAndTracking() async {
    await _trackingService?.stopTracking();
    if (mounted) {
      setState(() {
        _isAlarmRinging = false;
        _isTracking = false;
        _etaMinutes = 0;
      });
    }
  }

  Future<void> _loadStations() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    
    // Check if selected city is Kolkata
    // Assuming City enum or object has a name or id property. 
    // Based on app_state_provider.dart, it uses a City enum/class.
    // Let's assume City.kolkata exists or string check. 
    // I need to verify City enum in 'lib/core/constants/cities.dart' first? 
    // The user said "location kolkata is selected". 
    // I'll check the City enum values via the provider usage.
    
    if (appState.selectedCity.name.toLowerCase() != 'kolkata') {
      setState(() {
        _stations = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _metroService.loadNetwork();
      if (mounted) {
        setState(() {
          _stations = _metroService.getStations();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stations: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _calculateAndStartTrip() async {
    HapticFeedback.mediumImpact();

    if (_startStation == null || _endStation == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end stations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_startStation == _endStation) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start and end stations cannot be the same'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _blockedStations = [];
    });

    // Artificial delay for UX
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final route = _metroService.findRoute(_startStation!, _endStation!);

      // Get blocked stations on the ideal (unrestricted) path
      final blocked = _metroService.getBlockedStationsOnIdealPath(
        _startStation!,
        _endStation!,
      );

      if (route == null) {
        // Scenario A: No route available
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _calculatedRoute = null;
            _blockedStations = blocked;
          });
          if (blocked.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No metro route available between these stations'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Scenario B: Route found (may be alternate)
        HapticFeedback.lightImpact();
        if (mounted) {
          setState(() {
            _calculatedRoute = route;
            _blockedStations = blocked;
          });
          _saveTripToHistory(route);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calculating route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTripToHistory(MetroRoute route) async {
    try {
      final appState = context.read<AppStateProvider>();
      final tripProvider = context.read<TripProvider>();

      final trip = Trip(
        id: Trip.generateId(),
        transportMode: TransportMode.metro,
        city: appState.selectedCity.name,
        startStation: _startStation!,
        endStation: _endStation!,
        date: DateTime.now(),
        fare: route.totalFare,
        durationMinutes: route.totalTime,
      );

      await tripProvider.addTrip(trip);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route calculated & Trip saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Ignore history save errors silently or log
      debugPrint('Error saving trip: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metro Route'),
        backgroundColor: AppColors.metroColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.metroColor.withValues(alpha: 0.8),
                        AppColors.metroColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.subway, size: 48, color: Colors.white),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan Your Metro Trip',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Select your start and destination',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Route selection
                _buildStationSelector(
                  label: 'From',
                  icon: Icons.trip_origin,
                  value: _startStation,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _startStation = value;
                      _calculatedRoute = null; // Reset result on change
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Swap button
                Center(
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        final temp = _startStation;
                        _startStation = _endStation;
                        _endStation = temp;
                        _calculatedRoute = null;
                      });
                    },
                    icon: const Icon(Icons.swap_vert),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.metroColor.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildStationSelector(
                  label: 'To',
                  icon: Icons.location_on,
                  value: _endStation,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _endStation = value;
                      _calculatedRoute = null;
                    });
                  },
                ),
                const SizedBox(height: 32),

                // Calculate button
                ElevatedButton(
                  onPressed: _isLoading ? null : _calculateAndStartTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.metroColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Find Route',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),

                if (_blockedStations.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildBlockedStationsBanner(),
                ],

                if (_calculatedRoute != null) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildRouteResult(_calculatedRoute!),
                  const SizedBox(height: 24),

                  // Animated transition: idle ↔ active navigation dashboard
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1.0,
                            child: child,
                          ),
                        ),
                    child: _isTracking
                        ? _buildLiveNavigationDashboard()
                        : _buildStartTrackingButton(),
                  ),
                ],
              ],
            ),
          ),
          // Full-screen alarm overlay
          if (_isAlarmRinging)
            Container(
              color: Colors.black87,
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.alarm_on, size: 80, color: Colors.white),
                  const SizedBox(height: 24),
                  const Text(
                    'Get ready!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Arriving at $_alarmDestStation\nin ~${_alarmRemainingMins.round()} mins',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 220,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _stopAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'STOP ALARM',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _stopAlarmAndTracking,
                    child: const Text(
                      'Stop Alarm & End Trip',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────── Start Tracking Button (idle state) ───────────

  Widget _buildStartTrackingButton() {
    return Container(
      key: const ValueKey('idle'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: ElevatedButton.icon(
        onPressed: _toggleTracking,
        icon: const Icon(Icons.navigation),
        label: const Text('Start Live Tracking'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  // ─────────── Live Navigation Dashboard (active state) ───────────

  Widget _buildLiveNavigationDashboard() {
    // Progress calculation
    final double progress = _totalRouteTime > 0
        ? ((_totalRouteTime - _etaMinutes) / _totalRouteTime).clamp(0.0, 1.0)
        : 0.0;
    final int elapsedMins = (_totalRouteTime - _etaMinutes).round().clamp(0, _totalRouteTime);

    return Container(
      key: const ValueKey('active'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Status Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Pulsing dot
                _PulsingDot(color: Colors.greenAccent.shade400),
                const SizedBox(width: 10),
                const Text(
                  'Live Tracking Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                // GPS / Timer badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _gpsActive
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _gpsActive
                          ? Colors.greenAccent.shade200
                          : Colors.orangeAccent.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _gpsActive ? '🛰️' : '⏱️',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _gpsActive ? 'GPS' : 'Timer',
                        style: TextStyle(
                          color: _gpsActive ? Colors.greenAccent : Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                // ── Large ETA metrics ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_etaMinutes.round()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'min\nremaining',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$elapsedMins min elapsed',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(progress * 100).round()}% complete',
                          style: TextStyle(
                            color: Colors.greenAccent.shade200,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Progress Bar ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress < 0.7
                          ? Colors.greenAccent.shade400
                          : progress < 0.9
                              ? Colors.orangeAccent
                              : Colors.redAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Destination label ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 18, color: Colors.redAccent.shade100),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Heading to $_destStationName',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── End Trip button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      _toggleTracking();
                    },
                    icon: const Icon(Icons.stop_circle_outlined, size: 20),
                    label: const Text('End Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade200,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationSelector({
    required String label,
    required IconData icon,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    // If the current value is a disabled station, reset it
    final safeValue = (value != null && _metroService.isStationDisabled(value))
        ? null
        : value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.metroColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.metroColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: safeValue,
                    hint: const Text('Select station'),
                    isExpanded: true,
                    items: _stations.map((station) {
                      final isDisabled = _metroService.isStationDisabled(station);
                      
                      // If disabled, setting value to null makes it unselectable natively
                      final dropdownValue = isDisabled ? null : station;

                      return DropdownMenuItem<String>(
                        value: dropdownValue,
                        child: isDisabled
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$station (Out of Service)',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.info_outline, color: Colors.grey, size: 16),
                                ],
                              )
                            : Text(
                                station,
                                overflow: TextOverflow.ellipsis,
                              ),
                      );
                    }).toList(),
                    onChanged: (selected) {
                      if (selected != null && _metroService.isStationDisabled(selected)) {
                        // This fallback is kept just in case, but native null value 
                        // should prevent selection before it even hits this callback.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This station is currently out of service and cannot be selected.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      onChanged(selected);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteResult(MetroRoute route) {
    // 1. Build list of steps
    final List<Map<String, dynamic>> steps = [];
    
    // Boarding Step
    if (route.segments.isNotEmpty) {
      final start = route.segments.first;
      steps.add({
        'type': 'board',
        'station': start.station,
        'line': start.line,
        'text': 'Board at ${start.station} (${start.line} Line)',
      });
    }

    // Interchange Steps
    for (int i = 0; i < route.segments.length - 1; i++) {
      // final current = route.segments[i];
      // final next = route.segments[i+1];
      
      // If line changes, the connection point (current.station? No wait.)
      // The segments are edges. 
      // Segment[i] is [Station A -> Station B] on Line X.
      // Segment[i+1] is [Station B -> Station C] on Line Y.
      // If Line X != Line Y, then Station B is the interchange.
      // Station B is `next.station` of Segment[i]? No, segments structure in service:
      // Segment: station, line, time, fare.
      // In `MetroService`:
      // segments currently list STATIONS in order. 
      // Segment 0: Start Station (Line X - the line starting FROM it)
      // Segment 1: Station 2 (Line X - the line connected TO it)
      // Wait, let's re-verify MetroService structure.
      // Ah, I made `segments` list *stations*.
      // _calculateRouteDetails:
      // segments.insert(0, RouteSegment(station: start, line: segments.first.line...))
      // So detailed segments list: [Start, Station2, ..., End]
      // Segment i's line property is the line connecting TO that station from previous.
      // Except for Start, which I hacked to use next line.
      
      // Let's trace:
      // Path: A (Blue) -> B (Blue). B's segment has Blue.
      // Path: B (Blue) -> C (Green). C's segment has Green.
      // Line change detected: Previous Line (Blue) != Current Line (Green).
      // Interchange Station is previous station: B.
      // In segments list: [A, B, C].
      // A (Blue), B (Blue - coming from A), C (Green - coming from B).
      // Loop i from 1 to length.
      // current = segments[i].
      // prev = segments[i-1].
      // if (current.line != prev.line), then prev.station is interchange?
      // Wait. B connects A and C.
      // A->B is Blue. B's segment line is Blue.
      // B->C is Green. C's segment line is Green.
      // So at C, we see line is Green. Prev was Blue.
      // So the switch happened AT B.
      // Steps:
      // 1. Board at A (Blue).
      // 2. Loop: At C, line is Green. Switch from Blue. Station is B.
      // Add step: Change at B (Switch to Green).
      
      // Correct Logic:
      // Iterate starting from index 1.
      // If segments[i].line != segments[i-1].line
      //   Interchange is segments[i-1].station.
      //   New line is segments[i].line.
    }
    
    // Re-loop with correct logic
    for (int i = 1; i < route.segments.length; i++) {
      final currentLine = route.segments[i].line;
      final prevLine = route.segments[i-1].line;
      
      if (currentLine != prevLine) {
         final interchangeStation = route.segments[i-1].station;
         steps.add({
           'type': 'change',
           'station': interchangeStation,
           'line': currentLine,
           'text': 'Change at $interchangeStation (Switch to $currentLine Line)',
         });
      }
    }

    // Destination Step
    if (route.segments.isNotEmpty) {
      final end = route.segments.last;
      steps.add({
        'type': 'depart',
        'station': end.station,
        'line': end.line, // Line arriving at destination
        'text': 'Depart at ${end.station}',
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Route Details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.timer,
                label: 'Approx. Time',
                value: '${route.totalTime} mins',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.currency_rupee,
                label: 'Total Fare',
                value: '₹${route.totalFare.toStringAsFixed(0)}',
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        Text(
          'Journey Steps',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        // Simplified Steps List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: steps.length,
          itemBuilder: (context, index) {
            final step = steps[index];
            final type = step['type'];
            final isLast = index == steps.length - 1;
            
            Color iconColor;
            IconData icon;
            
            if (type == 'board') {
              iconColor = Colors.green;
              icon = Icons.directions_subway;
            } else if (type == 'change') {
              iconColor = Colors.orange;
              icon = Icons.transfer_within_a_station;
            } else {
              iconColor = Colors.red;
              icon = Icons.location_on;
            }

            return IntrinsicHeight(
              child: Row(
                children: [
                   // Timeline
                   SizedBox(
                    width: 40,
                    child: Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: iconColor, width: 2),
                          ),
                          child: Icon(icon, size: 16, color: iconColor),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                            ),
                          ),
                      ],
                    ),
                   ),
                   const SizedBox(width: 12),
                   
                   // Content
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.only(bottom: 24), // Spacing between steps
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             step['text'],
                             style: const TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                           if (type == 'board') ...[
                             const SizedBox(height: 4),
                             Text(
                               'Start your journey here',
                               style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                             ),
                           ],
                         ],
                       ),
                     ),
                   ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedStationsBanner() {
    final bool noRoute = _calculatedRoute == null;
    final Color bannerColor = noRoute ? Colors.red : Colors.orange;
    final String message = noRoute
        ? 'Cannot find a route. The following stations are currently out of service:'
        : 'Showing alternative route as any of these stations are out of service';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                noRoute ? Icons.error_outline : Icons.info_outline,
                color: bannerColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  noRoute ? 'Route Unavailable' : 'Service Disruption',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: bannerColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _blockedStations.map((info) {
              final String name = info['station'] as String;
              final String line = info['line'] as String;
              final Color chipColor = _lineColor(line);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: chipColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: chipColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: chipColor.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($line)',
                      style: TextStyle(
                        fontSize: 11,
                        color: chipColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _lineColor(String lineName) {
    switch (lineName.toLowerCase()) {
      case 'blue':   return const Color(0xFF3B82F6);
      case 'green':  return const Color(0xFF10B981);
      case 'orange': return const Color(0xFFF97316);
      case 'purple': return const Color(0xFF8B5CF6);
      case 'yellow': return const Color(0xFFEAB308);
      case 'red':    return const Color(0xFFEF4444);
      default:       return Colors.grey;
    }
  }
}

// ─────────── Pulsing dot animation ───────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _opacity.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _opacity.value * 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
