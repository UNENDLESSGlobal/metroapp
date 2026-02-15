import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transport_mode.dart';
import '../models/trip.dart';
import '../providers/app_state_provider.dart';
import '../providers/trip_provider.dart';
import '../core/constants/app_colors.dart';

/// Train route selection screen
class TrainRouteScreen extends StatefulWidget {
  const TrainRouteScreen({super.key});

  @override
  State<TrainRouteScreen> createState() => _TrainRouteScreenState();
}

class _TrainRouteScreenState extends State<TrainRouteScreen> {
  String? _startStation;
  String? _endStation;
  bool _isLoading = false;

  // Sample train stations
  final List<String> _stations = [
    'Central Railway',
    'Junction',
    'Suburban Terminal',
    'Express Hub',
    'North Station',
    'South Station',
    'East End',
    'West Terminal',
    'Industrial Siding',
    'Beach Terminus',
  ];

  Future<void> _startTrip() async {
    if (_startStation == null || _endStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end stations'),
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
        transportMode: TransportMode.train,
        city: appState.selectedCity.name,
        startStation: _startStation!,
        endStation: _endStation!,
        date: DateTime.now(),
        fare: 35.0,
        durationMinutes: 45,
      );

      await tripProvider.addTrip(trip);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Train trip started!'),
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
        title: const Text('Train Route'),
        backgroundColor: AppColors.trainColor,
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
                  colors: [AppColors.trainColor.withValues(alpha: 0.8), AppColors.trainColor],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.train, size: 48, color: Colors.white),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plan Your Train Trip',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(height: 4),
                        Text('Select stations', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSelector('From', Icons.trip_origin, _startStation, (v) => setState(() => _startStation = v)),
            const SizedBox(height: 16),
            Center(
              child: IconButton(
                onPressed: () => setState(() {
                  final t = _startStation;
                  _startStation = _endStation;
                  _endStation = t;
                }),
                icon: const Icon(Icons.swap_vert),
                style: IconButton.styleFrom(backgroundColor: AppColors.trainColor.withValues(alpha: 0.1)),
              ),
            ),
            const SizedBox(height: 16),
            _buildSelector('To', Icons.location_on, _endStation, (v) => setState(() => _endStation = v)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _startTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.trainColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Start Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
              color: AppColors.trainColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.trainColor),
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
                    hint: const Text('Select station'),
                    isExpanded: true,
                    items: _stations.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
