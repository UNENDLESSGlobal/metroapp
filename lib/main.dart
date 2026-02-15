import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core
import 'core/constants/app_theme.dart';

// Services
import 'services/auth_service.dart';

// Providers
import 'providers/app_state_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/alarm_settings_provider.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/metro_route_screen.dart';
import 'screens/bus_route_screen.dart';
import 'screens/train_route_screen.dart';
import 'screens/rickshaw_route_screen.dart';
import 'screens/history_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/about_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';

// TODO: Replace with your Supabase credentials
const String supabaseUrl = 'https://sabpglebxoncdaiwdiwv.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhYnBnbGVieG9uY2RhaXdkaXd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzNjAyNjQsImV4cCI6MjA4NTkzNjI2NH0.U9wqHfRoKS4DH-eZkbnUAbnkpt9UUyKL7-psjMYZus4';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  runApp(const MetroApp());
}

class MetroApp extends StatelessWidget {
  const MetroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // App state provider
        ChangeNotifierProvider(
          create: (_) => AppStateProvider()..init(),
        ),
        
        // Auth provider
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            AuthService(Supabase.instance.client),
          ),
        ),
        
        // Trip provider
        ChangeNotifierProvider(
          create: (_) => TripProvider()..loadTrips(),
        ),
        
        // Alarm Settings provider
        ChangeNotifierProvider(
          create: (_) => AlarmSettingsProvider()..init(),
        ),
      ],
      child: Consumer<AppStateProvider>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'Metro App',
            debugShowCheckedModeBanner: false,
            
            // Theme configuration
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appState.themeMode,
            
            // Initial route based on auth state
            initialRoute: Supabase.instance.client.auth.currentSession != null 
                ? '/home' 
                : '/login',
            
            // Route configuration
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/metro-route': (context) => const MetroRouteScreen(),
              '/bus-route': (context) => const BusRouteScreen(),
              '/train-route': (context) => const TrainRouteScreen(),
              '/rickshaw-route': (context) => const RickshawRouteScreen(),
              '/history': (context) => const HistoryScreen(),
              '/feedback': (context) => const FeedbackScreen(),
              '/about': (context) => const AboutScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/profile': (context) => const ProfileScreen(),
            },
            
            // Auth state listener
            builder: (context, child) {
              return _AuthStateListener(child: child!);
            },
          );
        },
      ),
    );
  }
}

/// Listen to auth state changes and redirect accordingly
class _AuthStateListener extends StatefulWidget {
  final Widget child;

  const _AuthStateListener({required this.child});

  @override
  State<_AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<_AuthStateListener> {
  @override
  void initState() {
    super.initState();
    
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((AuthState state) {
      if (mounted) {
        if (state.event == AuthChangeEvent.signedIn) {
          Navigator.pushReplacementNamed(context, '/home');
        } else if (state.event == AuthChangeEvent.signedOut) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
