import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/cities.dart';
import '../providers/app_state_provider.dart';
import '../services/location_service.dart';

/// City selection dropdown with auto-detect option
class CityDropdown extends StatefulWidget {
  final bool showAutoDetect;

  const CityDropdown({
    super.key,
    this.showAutoDetect = true,
  });

  @override
  State<CityDropdown> createState() => _CityDropdownState();
}

class _CityDropdownState extends State<CityDropdown> {
  final LocationService _locationService = LocationService();

  Future<void> _autoDetectCity() async {
    final appState = context.read<AppStateProvider>();
    appState.setDetectingLocation(true);

    try {
      final city = await _locationService.autoDetectCity();
      if (city != null && mounted) {
        appState.setCity(city);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location detected: ${city.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect location. Please select manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location detection failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        appState.setDetectingLocation(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        final theme = Theme.of(context);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(50), // Pill shape
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<City?>(
              value: appState.selectedCity,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded, 
                color: theme.colorScheme.onPrimaryContainer
              ),
              dropdownColor: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins', 
              ),
              selectedItemBuilder: (context) {
                // Only show the city name when selected, even if "Detect" was clicked
                return [
                  // Option for "Detect Location" placeholder if needed (not strictly used via creating list logic below)
                  const SizedBox.shrink(),
                   ...City.values.map((city) {
                    return Center(
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            city.name,
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ];
              },
              items: [
                // 1. Detect Current Location Option
                DropdownMenuItem<City?>(
                  value: null,
                  child: Row(
                    children: [
                      if (appState.isDetectingLocation)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else
                        Icon(
                          Icons.my_location, 
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      const SizedBox(width: 12),
                      Text(
                        'Auto Detect',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Divider-like item? No, DropdownButton doesn't support non-selectable dividers easily.
                // We'll just list cities.
                
                // 2. City Options
                ...City.values.map((city) {
                  return DropdownMenuItem<City?>(
                    value: city,
                    child: Text(
                      city.name,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                }),
              ],
              onChanged: (City? city) {
                if (city == null) {
                  // Detect location clicked
                  _autoDetectCity();
                } else {
                  appState.setCity(city);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
