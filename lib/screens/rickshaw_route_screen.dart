import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transport_mode.dart';
import '../models/trip.dart';
import '../providers/app_state_provider.dart';
import '../providers/trip_provider.dart';
import '../core/constants/app_colors.dart';

/// Rickshaw/Auto route selection screen
class RickshawRouteScreen extends StatefulWidget {
  const RickshawRouteScreen({super.key});

  @override
  State<RickshawRouteScreen> createState() => _RickshawRouteScreenState();
}

class _RickshawRouteScreenState extends State<RickshawRouteScreen> {
  String? _pickup;
  String? _dropoff;
  bool _isLoading = false;

  // Sample locations
  final List<String> _locations = [
    'Auto Stand',
    'Main Market',
    'Bus Stand',
    'Railway Station',
    'Hospital',
    'School',
    'Temple Road',
    'Garden Area',
    'Cinema Hall',
    'Food Street',
  ];

  Future<void> _startTrip() async {
    if (_pickup == null || _dropoff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup and drop-off locations'),
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
        transportMode: TransportMode.rickshaw,
        city: appState.selectedCity.name,
        startStation: _pickup!,
        endStation: _dropoff!,
        date: DateTime.now(),
        fare: 50.0,
        durationMinutes: 20,
      );

      await tripProvider.addTrip(trip);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rickshaw ride started!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto/Rickshaw'),
        backgroundColor: AppColors.rickshawColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.rickshawColor.withValues(alpha: 0.8), AppColors.rickshawColor],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.electric_rickshaw, size: 48, color: Colors.white),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Book Your Ride',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 4),
                        Text('Quick and convenient travel', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSelector('Pickup', Icons.my_location, _pickup, (v) => setState(() => _pickup = v)),
            const SizedBox(height: 16),
            Center(
              child: IconButton(
                onPressed: () => setState(() {
                  final t = _pickup;
                  _pickup = _dropoff;
                  _dropoff = t;
                }),
                icon: const Icon(Icons.swap_vert),
                style: IconButton.styleFrom(backgroundColor: AppColors.rickshawColor.withValues(alpha: 0.1)),
              ),
            ),
            const SizedBox(height: 16),
            _buildSelector('Drop-off', Icons.location_on, _dropoff, (v) => setState(() => _dropoff = v)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _startTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rickshawColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Start Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelector(String label, IconData icon, String? value, ValueChanged<String?> onChanged) {
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
              color: AppColors.rickshawColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.rickshawColor),
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
                    hint: const Text('Select location'),
                    isExpanded: true,
                    items: _locations.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
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
