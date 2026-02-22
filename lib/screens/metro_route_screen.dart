import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transport_mode.dart';
import '../models/trip.dart';
import '../providers/app_state_provider.dart';
import '../providers/trip_provider.dart';
import '../core/constants/app_colors.dart';
import '../services/metro_service.dart';
import '../services/trip_tracking_service.dart';


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
  
  // Tracking State
  TripTrackingService? _trackingService;
  bool _isTracking = false;
  String _trackingStatus = '';
  bool _isAlarmRinging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStations();
      _initTracking();
    });
  }
  
  void _initTracking() async {
      // Create instances. 
      // Note: AlarmSettingsProvider should be available above in widget tree.
      // Ensure MultiProvider includes it in main.dart or where appropriate.
      try {
        _trackingService = TripTrackingService(_metroService);
        await _trackingService?.init();
        
        _trackingService?.onStatusUpdate = (status) {
           if (mounted) setState(() => _trackingStatus = status);
        };
        
        _trackingService?.onAlarmTriggered = () {
           if (mounted) setState(() => _isAlarmRinging = true);
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
      await _trackingService?.stopTracking();
      if (mounted) {
        setState(() {
          _isTracking = false;
          _trackingStatus = '';
          _isAlarmRinging = false;
        });
      }
    } else {
      if (_calculatedRoute == null) return;
      await _trackingService?.startTracking(_calculatedRoute!);
      if (mounted) {
        setState(() => _isTracking = true);
      }
    }
  }
  
  Future<void> _stopAlarm() async {
      await _toggleTracking(); // Stop everything for now
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
    if (_startStation == null || _endStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end stations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_startStation == _endStation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start and end stations cannot be the same'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Artificial delay for UX
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final route = _metroService.findRoute(_startStation!, _endStation!);

      if (route == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No direct metro route available'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _calculatedRoute = route;
          });
          
          // Optionally save to history here if "Start Trip" implies actually taking it,
          // but usually users want to see the route first.
          // Let's add a separate "Save Trip" or "Go" button in the result view?
          // For now, I'll log it as per original code logic but also show the UI.
          
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

                if (_calculatedRoute != null) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildRouteResult(_calculatedRoute!),
                  const SizedBox(height: 24),

                  // Tracking Controls
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isTracking ? Colors.green.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isTracking ? Colors.green : Colors.blue,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_trackingStatus.isNotEmpty) ...[
                          Text(
                            _trackingStatus,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _isTracking ? Colors.green.shade800 : Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ElevatedButton.icon(
                          onPressed: _toggleTracking,
                          icon: Icon(_isTracking ? Icons.stop : Icons.navigation),
                          label: Text(_isTracking ? 'Stop Trip' : 'Start Live Tracking'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTracking ? Colors.red : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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
                    'Arriving Soon!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Please prepare to exit or change lines.',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 200,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _stopAlarm, // Stops alarm and tracking
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        'STOP ALARM',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      return DropdownMenuItem(
                        value: station,
                        child: isDisabled
                            ? Tooltip(
                                message: 'This station is currently out of service',
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        station,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.info_outline, color: Colors.grey, size: 16),
                                  ],
                                ),
                              )
                            : Text(
                                station,
                                overflow: TextOverflow.ellipsis,
                              ),
                      );
                    }).toList(),
                    onChanged: (selected) {
                      if (selected != null && _metroService.isStationDisabled(selected)) {
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
                label: 'Time',
                value: '${route.totalTime} mins',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                icon: Icons.currency_rupee,
                label: 'Fare',
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
}
