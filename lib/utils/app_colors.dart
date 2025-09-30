import 'package:flutter/material.dart';

/// App-wide color constants for consistent theming
class AppColors {
  // Prevent instantiation
  AppColors._();

  // Primary theme colors
  static const Color primary = Color(0xFF00E5FF); // Neon light blue
  static const Color secondary = Color(0xFF00FF88); // Neon light green

  // Background colors
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF121212);
  static const Color appBarBackground = Color(0xFF1E1E1E);

  // Text colors
  static const Color onPrimary = Colors.black;
  static const Color onSecondary = Colors.black;
  static const Color onSurface = Colors.white;
  static const Color onBackground = Colors.white;

  // Card colors
  static const Color cardBackground = Color(0xFF1E1E1E);
  static const Color cardBorder = Color(0xFF333333);

  // Button colors
  static const Color buttonBackground = Color(0xFF2A2A2A);
  static const Color buttonBorder = Color(0xFF555555);
  static const Color buttonText = Colors.white;

  // Selection colors
  static const Color selectedBackground = Color(0xFF00FF88);
  static const Color selectedBorder = Color(0xFF00FF88);
  static const Color unselectedBackground = Colors.transparent;
  static const Color unselectedBorder = Color(0xFF555555);
  static const Color unselectedText = Color(0xFF888888);

  // Player status colors
  static const Color playerOnCourt = Color(0xFF00FF88);
  static const Color playerOffCourt = Color(0xFF888888);

  // Event type colors
  static const Color serveColor = Color(0xFF00E5FF);
  static const Color passColor = Color(0xFF00FF88);
  static const Color attackColor = Color(0xFFFF8800);
  static const Color blockColor = Color(0xFF9C27B0);
  static const Color digColor = Color(0xFFFF4444);
  static const Color setColor = Color(0xFFFFFF00);
  static const Color freeballColor = Color(0xFF00FF00);

  // Rating colors
  static const Color aceRating = Color(0xFF4CAF50);
  static const Color goodRating = Color(0xFF8BC34A);
  static const Color okRating = Color(0xFFFFEB3B);
  static const Color poorRating = Color(0xFFFF9800);
  static const Color errorRating = Color(0xFFF44336);

  // Chart colors
  static const Color chartPrimary = Color(0xFF00E5FF);
  static const Color chartSecondary = Color(0xFF00FF88);
  static const Color chartTertiary = Color(0xFFFF6B6B);
  static const Color chartQuaternary = Color(0xFFFFD93D);

  // Court colors
  static const Color courtLine = Colors.white;
  static const Color courtBackground = Color(0xFF2D2D2D);
  static const Color courtInnerBackground = Color(0xFF1A1A1A);
  static const Color netColor = Color(0xFF888888);
  static const Color tenFootLineColor = Color(0xFF666666);
  static const Color zoneColor = Color(0xFF444444);

  // Coordinate colors
  static const Color startCoordinate = Color(0xFF4CAF50); // Green
  static const Color endCoordinate = Color(0xFFF44336); // Red

  // Border colors
  static const Color lightBorder = Color(0xFF555555);
  static const Color mediumBorder = Color(0xFF777777);
  static const Color darkBorder = Color(0xFF333333);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Opacity variants
  static Color get primaryWithOpacity20 => primary.withValues(alpha: 0.2);
  static Color get primaryWithOpacity50 => primary.withValues(alpha: 0.5);
  static Color get secondaryWithOpacity20 => secondary.withValues(alpha: 0.2);
  static Color get secondaryWithOpacity50 => secondary.withValues(alpha: 0.5);
  static Color get secondaryWithOpacity60 => secondary.withValues(alpha: 0.6);
  static Color get whiteWithOpacity50 => Colors.white.withValues(alpha: 0.5);
  static Color get blackWithOpacity50 => Colors.black.withValues(alpha: 0.5);

  // Grey variants
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Additional colors found in project
  static const Color gold = Color(0xFFFFD700);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color redError = Color(0xFFFF4444);
  static const Color orangeWarning = Color(0xFFFF8800);
  static const Color hybridBlue = Color(0xFF00B8D4);
  static const Color spinBlue = Color(0xFF0097A7);

  // Opacity variants for additional colors
  static Color get goldWithOpacity20 => gold.withValues(alpha: 0.2);
  static Color get primaryWithOpacity10 => primary.withValues(alpha: 0.1);
  static Color get redWithOpacity80 => Colors.red.withValues(alpha: 0.8);
  static Color get blackWithOpacity70 => Colors.black.withValues(alpha: 0.7);
}
