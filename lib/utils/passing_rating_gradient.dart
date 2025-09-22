import 'package:flutter/material.dart';
import 'dart:math' as math;

class PassingRatingGradient {
  // Define the gradient stops
  static const List<ColorStop> _colorStops = [
    ColorStop(0.0, Color(0xFFFF4444)), // Neon red
    ColorStop(2.0, Color(0xFFFF8800)), // Neon orange
    ColorStop(2.1, Color(0xFFFFFF00)), // Neon yellow
    ColorStop(2.2, Color(0xFF00FF88)), // Neon green
    ColorStop(3.0, Color.fromARGB(255, 1, 109, 1)), // Bright green
  ];

  /// Get the color for a given passing rating using linear interpolation
  static Color getColor(double rating) {
    // Clamp rating to the defined range
    rating = math.max(0.0, math.min(3.0, rating));

    // Find the two color stops to interpolate between
    for (int i = 0; i < _colorStops.length - 1; i++) {
      final currentStop = _colorStops[i];
      final nextStop = _colorStops[i + 1];

      if (rating >= currentStop.rating && rating <= nextStop.rating) {
        // Calculate interpolation factor (0.0 to 1.0)
        final factor =
            (rating - currentStop.rating) /
            (nextStop.rating - currentStop.rating);

        // Interpolate between the two colors
        return Color.lerp(currentStop.color, nextStop.color, factor)!;
      }
    }

    // Fallback to the last color if rating is at or above the maximum
    return _colorStops.last.color;
  }

  /// Get a gradient shader for use in text or other widgets
  static Shader getShader(Rect bounds) {
    return LinearGradient(
      colors: _colorStops.map((stop) => stop.color).toList(),
      stops: _colorStops.map((stop) => stop.rating / 3.0).toList(),
    ).createShader(bounds);
  }

  /// Get a linear gradient widget
  static LinearGradient getLinearGradient() {
    return LinearGradient(
      colors: _colorStops.map((stop) => stop.color).toList(),
      stops: _colorStops.map((stop) => stop.rating / 3.0).toList(),
    );
  }
}

class ColorStop {
  final double rating;
  final Color color;

  const ColorStop(this.rating, this.color);
}
