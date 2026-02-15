import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transport_mode.dart';
import '../providers/app_state_provider.dart';

import 'package:flutter/services.dart';

/// Bottom navigation bar for transport mode selection
class TransportBottomNav extends StatelessWidget {
  const TransportBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: TransportMode.values.map((mode) {
                  final isSelected = appState.selectedTransportMode == mode;
                  return _TransportNavItem(
                    mode: mode,
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      appState.setTransportMode(mode);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TransportNavItem extends StatelessWidget {
  final TransportMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _TransportNavItem({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? mode.color.withValues(alpha: 0.15) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(25), // Pill shape
          border: isSelected
              ? Border.all(color: mode.color, width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with pill shape
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? mode.color 
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20), // Pill-shaped icon
              ),
              child: Icon(
                mode.icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              mode.displayName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected 
                    ? mode.color 
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
