import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/player.dart';
import '../models/event.dart';

class ServingPieChart extends StatelessWidget {
  final List<Player> practicePlayers;
  final List<Event> teamEvents;
  final Map<String, dynamic> Function(List<Event>) getPlayerServingStats;

  const ServingPieChart({
    super.key,
    required this.practicePlayers,
    required this.teamEvents,
    required this.getPlayerServingStats,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate total serving types across all players
    final servingTypes = <String, int>{'float': 0, 'hybrid': 0, 'spin': 0};

    for (final player in practicePlayers) {
      final playerEvents = teamEvents
          .where((e) => e.player.id == player.id)
          .toList();
      final servingStats = getPlayerServingStats(playerEvents);

      servingTypes['float'] =
          (servingTypes['float'] ?? 0) + ((servingStats['float'] ?? 0) as int);
      servingTypes['hybrid'] =
          (servingTypes['hybrid'] ?? 0) +
          ((servingStats['hybrid'] ?? 0) as int);
      servingTypes['spin'] =
          (servingTypes['spin'] ?? 0) + ((servingStats['spin'] ?? 0) as int);
    }

    final totalServes = servingTypes.values.reduce((a, b) => a + b);
    if (totalServes == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Serving Types Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Total Serves: $totalServes',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        painter: PieChartPainter(servingTypes, totalServes),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLegend(servingTypes, totalServes),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Map<String, int> servingTypes, int totalServes) {
    final colors = {
      'float': const Color(0xFF00E5FF),
      'hybrid': const Color(0xFF00B8D4),
      'spin': const Color(0xFF0097A7),
    };

    final labels = {'float': 'Float', 'hybrid': 'Hybrid', 'spin': 'Spin'};

    return Column(
      children: servingTypes.entries.where((entry) => entry.value > 0).map((
        entry,
      ) {
        final percentage = (entry.value / totalServes * 100);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[entry.key],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${labels[entry.key]}: ${entry.value} (${percentage.toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final Map<String, int> data;
  final int total;

  PieChartPainter(this.data, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    final colors = {
      'float': const Color(0xFF00E5FF),
      'hybrid': const Color(0xFF00B8D4),
      'spin': const Color(0xFF0097A7),
    };

    double startAngle = -math.pi / 2; // Start from top

    for (final entry in data.entries) {
      if (entry.value > 0) {
        final sweepAngle = 2 * math.pi * (entry.value / total);

        final paint = Paint()
          ..color = colors[entry.key]!
          ..style = PaintingStyle.fill;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );

        // Add white border
        final borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          true,
          borderPaint,
        );

        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
