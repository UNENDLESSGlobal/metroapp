import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../models/transport_mode.dart';
import '../providers/trip_provider.dart';
import '../providers/app_state_provider.dart';

/// Card displaying last trips for the selected transport mode
class LastTripsCard extends StatelessWidget {
  final int maxTrips;

  const LastTripsCard({
    super.key,
    this.maxTrips = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<TripProvider, AppStateProvider>(
      builder: (context, tripProvider, appState, _) {
        final mode = appState.selectedTransportMode;
        final trips = tripProvider.getLastTripsForMode(mode, count: maxTrips);
        final hasTrips = trips.isNotEmpty;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: mode.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.history,
                      color: mode.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Last ${mode.displayName} Trips',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Content
              if (!hasTrips)
                _buildEmptyState(context, mode)
              else
                ...trips.map((trip) => _TripListItem(trip: trip)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, TransportMode mode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              mode.icon,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Start a trip to show history',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripListItem extends StatelessWidget {
  final Trip trip;

  const _TripListItem({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Transport icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: trip.transportMode.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              trip.transportMode.icon,
              color: trip.transportMode.color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          
          // Trip details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.startStation} → ${trip.endStation}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  trip.formattedDate,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // Fare (if available)
          if (trip.fare != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                trip.formattedFare,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
