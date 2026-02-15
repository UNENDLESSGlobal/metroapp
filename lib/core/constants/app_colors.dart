import 'package:flutter/material.dart';

/// App color scheme following the modern light blue + off-white design
class AppColors {
  // Primary Colors (Light Blue palette)
  static const Color primaryLight = Color(0xFF64B5F6);  // Light Blue 300
  static const Color primary = Color(0xFF42A5F5);       // Light Blue 400
  static const Color primaryDark = Color(0xFF1E88E5);   // Light Blue 600
  
  // Background Colors
  static const Color backgroundLight = Color(0xFFFAFAFA);  // Off-white
  static const Color backgroundDark = Color(0xFF121212);   // Dark mode background
  
  // Surface Colors
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  
  // Card Colors
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF2D2D2D);
  
  // Text Colors
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  
  // Accent Colors
  static const Color accent = Color(0xFF00BCD4);        // Cyan
  static const Color success = Color(0xFF4CAF50);       // Green
  static const Color warning = Color(0xFFFF9800);       // Orange
  static const Color error = Color(0xFFE53935);         // Red
  
  // Transport Mode Colors
  static const Color metroColor = Color(0xFF1565C0);    // Blue
  static const Color busColor = Color(0xFF43A047);      // Green
  static const Color trainColor = Color(0xFFE65100);    // Orange
  static const Color rickshawColor = Color(0xFF6A1B9A); // Purple
  
  // Gradient Colors for Start Button
  static const List<Color> primaryGradient = [
    Color(0xFF42A5F5),
    Color(0xFF1E88E5),
  ];
  
  // Shimmer/Loading Colors
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
}
