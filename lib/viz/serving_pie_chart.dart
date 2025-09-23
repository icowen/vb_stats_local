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
    final servingResults = <String, Map<String, int>>{
      'float': {'in': 0, 'error': 0, 'total': 0},
      'hybrid': {'in': 0, 'error': 0, 'total': 0},
      'spin': {'in': 0, 'error': 0, 'total': 0},
    };

    for (final player in practicePlayers) {
      final playerEvents = teamEvents
          .where((e) => e.player.id == player.id)
          .toList();
      final servingStats = getPlayerServingStats(playerEvents);

      // Count serve types
      servingTypes['float'] =
          (servingTypes['float'] ?? 0) + ((servingStats['float'] ?? 0) as int);
      servingTypes['hybrid'] =
          (servingTypes['hybrid'] ?? 0) +
          ((servingStats['hybrid'] ?? 0) as int);
      servingTypes['spin'] =
          (servingTypes['spin'] ?? 0) + ((servingStats['spin'] ?? 0) as int);

      // For now, we'll distribute the overall in/error results proportionally
      // since the current data structure doesn't track results per serve type
      final totalIn = (servingStats['in'] ?? 0) as int;
      final totalError = (servingStats['error'] ?? 0) as int;
      final totalServes = (servingStats['total'] ?? 0) as int;

      if (totalServes > 0) {
        final floatCount = (servingStats['float'] ?? 0) as int;
        final hybridCount = (servingStats['hybrid'] ?? 0) as int;
        final spinCount = (servingStats['spin'] ?? 0) as int;

        // Distribute in/error results proportionally based on serve type usage
        servingResults['float']!['total'] =
            (servingResults['float']!['total'] ?? 0) + floatCount;
        servingResults['hybrid']!['total'] =
            (servingResults['hybrid']!['total'] ?? 0) + hybridCount;
        servingResults['spin']!['total'] =
            (servingResults['spin']!['total'] ?? 0) + spinCount;

        if (floatCount > 0) {
          final floatRatio = floatCount / totalServes;
          servingResults['float']!['in'] =
              (servingResults['float']!['in'] ?? 0) +
              (totalIn * floatRatio).round();
          servingResults['float']!['error'] =
              (servingResults['float']!['error'] ?? 0) +
              (totalError * floatRatio).round();
        }
        if (hybridCount > 0) {
          final hybridRatio = hybridCount / totalServes;
          servingResults['hybrid']!['in'] =
              (servingResults['hybrid']!['in'] ?? 0) +
              (totalIn * hybridRatio).round();
          servingResults['hybrid']!['error'] =
              (servingResults['hybrid']!['error'] ?? 0) +
              (totalError * hybridRatio).round();
        }
        if (spinCount > 0) {
          final spinRatio = spinCount / totalServes;
          servingResults['spin']!['in'] =
              (servingResults['spin']!['in'] ?? 0) +
              (totalIn * spinRatio).round();
          servingResults['spin']!['error'] =
              (servingResults['spin']!['error'] ?? 0) +
              (totalError * spinRatio).round();
        }
      }
    }

    final totalServes = servingTypes.values.reduce((a, b) => a + b);
    if (totalServes == 0) {
      return const SizedBox.shrink();
    }

    // Calculate total stats across all players
    int totalMakes = 0;
    int totalErrors = 0;
    int totalAces = 0;

    for (final player in practicePlayers) {
      final playerEvents = teamEvents
          .where((e) => e.player.id == player.id)
          .toList();
      final servingStats = getPlayerServingStats(playerEvents);

      totalMakes += (servingStats['in'] ?? 0) as int;
      totalErrors += (servingStats['error'] ?? 0) as int;
      totalAces += (servingStats['ace'] ?? 0) as int;
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
            const SizedBox(height: 8),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  context,
                  'Makes',
                  totalMakes,
                  const Color(0xFF00FF88),
                ),
                _buildStatItem(
                  context,
                  'Errors',
                  totalErrors,
                  const Color(0xFFFF4444),
                ),
                _buildStatItem(
                  context,
                  'Attempts',
                  totalServes,
                  const Color(0xFF00E5FF),
                ),
                _buildStatItem(
                  context,
                  'Aces',
                  totalAces,
                  const Color(0xFFFFFF00),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  // Pie Chart
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 150,
                            child: CustomPaint(
                              painter: PieChartPainter(
                                servingTypes,
                                totalServes,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildLegend(servingTypes, totalServes),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bar Chart
                  Expanded(child: _buildBarChart(context, servingResults)),
                ],
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

  Widget _buildBarChart(
    BuildContext context,
    Map<String, Map<String, int>> servingResults,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: servingResults.entries.map((entry) {
              final serveType = entry.key;
              final results = entry.value;
              final total = results['total'] ?? 0;
              final inCount = results['in'] ?? 0;
              final errorCount = results['error'] ?? 0;

              // Calculate actual percentages for this serve type
              final makePercentage = total > 0 ? inCount / total : 0.0;
              final missPercentage = total > 0 ? errorCount / total : 0.0;

              return _buildBarChartBar(
                context,
                serveType,
                makePercentage,
                missPercentage,
                inCount,
                errorCount,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartBar(
    BuildContext context,
    String serveType,
    double makePercentage,
    double missPercentage,
    int inCount,
    int errorCount,
  ) {
    final labels = {'float': 'Float', 'hybrid': 'Hybrid', 'spin': 'Spin'};

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          labels[serveType]!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 20,
          width: 120,
          child: _buildBarSegments(
            makePercentage,
            missPercentage,
            inCount,
            errorCount,
          ),
        ),
      ],
    );
  }

  Widget _buildBarSegments(
    double makePercentage,
    double missPercentage,
    int inCount,
    int errorCount,
  ) {
    final makePercent = (makePercentage * 100).round();
    final missPercent = (missPercentage * 100).round();

    // If both are 0, show empty bar with label
    if (makePercent == 0 && missPercent == 0) {
      return Container(
        height: 20,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            'No data',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // If only makes, show full green bar
    if (missPercent == 0) {
      return Tooltip(
        message: 'Makes: ${makePercent}% ($inCount)',
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF00FF88),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${makePercent}%',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    // If only misses, show full red bar
    if (makePercent == 0) {
      return Tooltip(
        message: 'Misses: ${missPercent}% ($errorCount)',
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFF4444),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '${missPercent}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    // Both have values, show split bar
    return Row(
      children: [
        // Make percentage (green)
        Expanded(
          flex: makePercent,
          child: Tooltip(
            message: 'Makes: ${makePercent}% ($inCount)',
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF00FF88),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  '${makePercent}%',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Miss percentage (red)
        Expanded(
          flex: missPercent,
          child: Tooltip(
            message: 'Misses: ${missPercent}% ($errorCount)',
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFF4444),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  '${missPercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    int value,
    Color color,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
