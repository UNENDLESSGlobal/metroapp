import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../providers/alarm_settings_provider.dart';
import '../core/constants/app_colors.dart';

/// Settings screen with theme toggle
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance section
          _buildSectionHeader(context, 'Appearance'),
          const SizedBox(height: 8),
          _buildThemeToggle(context),
          
          const SizedBox(height: 24),
          
          // About section
          _buildSectionHeader(context, 'About'),
          const SizedBox(height: 8),
          _buildInfoTile(
            context,
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0',
          ),
          _buildInfoTile(
            context,
            icon: Icons.code,
            title: 'Build',
            subtitle: '1',
          ),

          const SizedBox(height: 24),

          // Alarm & Audio section
          _buildSectionHeader(context, 'Alarm & Audio'),
          const SizedBox(height: 8),
          Consumer<AlarmSettingsProvider>(
            builder: (context, alarmSettings, _) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Enable Sound'),
                      subtitle: const Text('Play audio alarm when near station'),
                      value: alarmSettings.isSoundEnabled,
                      onChanged: (val) => alarmSettings.setSoundEnabled(val),
                      activeTrackColor: AppColors.primary,
                    ),
                  ),
                  if (alarmSettings.isSoundEnabled) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text('Volume'),
                        subtitle: Slider(
                          value: alarmSettings.volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: '${(alarmSettings.volume * 100).round()}%',
                          activeColor: AppColors.primary,
                          onChanged: (val) => alarmSettings.setVolume(val),
                        ),
                      ),
                    ),

                  ],
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Enable Vibration'),
                      subtitle: const Text('Vibrate when alarm triggers'),
                      value: alarmSettings.isVibrateEnabled,
                      onChanged: (val) => alarmSettings.setVibrateEnabled(val),
                      activeTrackColor: AppColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                appState.themeMode == ThemeMode.dark 
                    ? Icons.dark_mode 
                    : appState.themeMode == ThemeMode.light 
                        ? Icons.light_mode 
                        : Icons.brightness_auto,
                color: AppColors.primary,
              ),
            ),
            title: const Text(
              'Theme',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              appState.themeMode == ThemeMode.dark 
                  ? 'Dark Mode' 
                  : appState.themeMode == ThemeMode.light 
                      ? 'Light Mode' 
                      : 'System Default',
            ),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<ThemeMode>(
                value: appState.themeMode,
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('System Default'),
                  ),
                ],
                onChanged: (ThemeMode? newMode) {
                  if (newMode != null) {
                    appState.setThemeMode(newMode);
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.grey.shade600),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
      ),
    );
  }
}
