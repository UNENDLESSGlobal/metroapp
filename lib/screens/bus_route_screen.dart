import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transport_mode.dart';
import '../models/trip.dart';
import '../providers/app_state_provider.dart';
import '../providers/trip_provider.dart';
import '../core/constants/app_colors.dart';

/// Bus route selection screen
class BusRouteScreen extends StatefulWidget {
  const BusRouteScreen({super.key});

  @override
  State<BusRouteScreen> createState() => _BusRouteScreenState();
}

class _BusRouteScreenState extends State<BusRouteScreen> {
  String? _startStop;
  String? _endStop;
  bool _isLoading = false;

  // Sample bus stops
  final List<String> _stops = [
    'Bus Terminal',
    'Market Square',
    'School Road',
    'Hospital Gate',
    'Park Avenue',
    'Shopping Mall',
    'College Campus',
    'Industrial Area',
    'Residential Complex',
    'Stadium',
  ];

  Future<void> _startTrip() async {
    if (_startStop == null || _endStop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end stops'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appState = context.read<AppStateProvider>();
      final tripProvider = context.read<TripProvider>();

      final trip = Trip(
        id: Trip.generateId(),
        transportMode: TransportMode.bus,
        city: appState.selectedCity.name,
        startStation: _startStop!,
        endStation: _endStop!,
        date: DateTime.now(),
        fare: 15.0,
        durationMinutes: 25,
      );

      await tripProvider.addTrip(trip);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bus trip started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Route'),
        backgroundColor: AppColors.busColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.busColor.withValues(alpha: 0.8),
                    AppColors.busColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.directions_bus, size: 48, color: Colors.white),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan Your Bus Trip',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select your boarding and drop-off points',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildStopSelector(
              label: 'Boarding Point',
              icon: Icons.trip_origin,
              value: _startStop,
              onChanged: (v) => setState(() => _startStop = v),
            ),
            const SizedBox(height: 16),
            Center(
              child: IconButton(
                onPressed: () {
                  setState(() {
                    final temp = _startStop;
                    _startStop = _endStop;
                    _endStop = temp;
                  });
                },
                icon: const Icon(Icons.swap_vert),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.busColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildStopSelector(
              label: 'Drop-off Point',
              icon: Icons.location_on,
              value: _endStop,
              onChanged: (v) => setState(() => _endStop = v),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _startTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.busColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Start Trip',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopSelector({
    required String label,
    required IconData icon,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.busColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.busColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    hint: const Text('Select stop'),
                    isExpanded: true,
                    items: _stops.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
