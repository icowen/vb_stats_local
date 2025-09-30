import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/player.dart';
import '../models/event.dart';
import '../utils/app_colors.dart';

class ServingPieChart extends StatefulWidget {
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
  State<ServingPieChart> createState() => _ServingPieChartState();
}

class _ServingPieChartState extends State<ServingPieChart> {
  @override
  Widget build(BuildContext context) {
    // Calculate total serving types across all players
    final servingTypes = <String, int>{'float': 0, 'hybrid': 0, 'spin': 0};
    final servingResults = <String, Map<String, int>>{
      'float': {'in': 0, 'ace': 0, 'error': 0, 'total': 0},
      'hybrid': {'in': 0, 'ace': 0, 'error': 0, 'total': 0},
      'spin': {'in': 0, 'ace': 0, 'error': 0, 'total': 0},
    };

    // Process each serve event to get accurate results per serve type
    final serveEvents = widget.teamEvents
        .where((e) => e.type == EventType.serve)
        .toList();

    for (final event in serveEvents) {
      final serveType = event.metadata['serveType'] as String?;
      final result = event.metadata['result'] as String?;

      if (serveType != null &&
          (serveType == 'float' ||
              serveType == 'hybrid' ||
              serveType == 'spin')) {
        // Count all serves with serve types as attempts
        servingTypes[serveType] = (servingTypes[serveType] ?? 0) + 1;
        servingResults[serveType]!['total'] =
            (servingResults[serveType]!['total'] ?? 0) + 1;

        // Count results for this specific serve type (only if result exists)
        if (result != null) {
          if (result == 'in') {
            servingResults[serveType]!['in'] =
                (servingResults[serveType]!['in'] ?? 0) + 1;
          } else if (result == 'ace') {
            servingResults[serveType]!['ace'] =
                (servingResults[serveType]!['ace'] ?? 0) + 1;
          } else if (result == 'error') {
            servingResults[serveType]!['error'] =
                (servingResults[serveType]!['error'] ?? 0) + 1;
          }
        }
      }
    }

    final totalServes = servingTypes.values.reduce((a, b) => a + b);
    if (totalServes == 0) {
      return const SizedBox.shrink();
    }

    // Calculate total stats from the accurate serving results
    int totalMakes = 0;
    int totalErrors = 0;
    int totalAces = 0;

    for (final results in servingResults.values) {
      totalMakes += results['in'] ?? 0;
      totalErrors += results['error'] ?? 0;
    }

    // Calculate aces separately from serve events (aces are already included in totalMakes)
    for (final event in serveEvents) {
      final result = event.metadata['result'] as String?;
      if (result == 'ace') {
        totalAces++;
      }
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
                  AppColors.secondary,
                ),
                _buildStatItem(
                  context,
                  'Errors',
                  totalErrors,
                  AppColors.redError,
                ),
                _buildStatItem(
                  context,
                  'Attempts',
                  totalServes,
                  AppColors.primary,
                ),
                _buildStatItem(context, 'Aces', totalAces, AppColors.setColor),
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
      'float': AppColors.primary,
      'hybrid': AppColors.hybridBlue,
      'spin': AppColors.spinBlue,
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
    // Calculate totals for "All" bar
    int totalMakes = 0;
    int totalAces = 0;
    int totalErrors = 0;

    for (final results in servingResults.values) {
      totalMakes += results['in'] ?? 0;
      totalAces += results['ace'] ?? 0;
      totalErrors += results['error'] ?? 0;
    }

    final totalSuccessful = totalMakes + totalAces;
    final totalWithResults = totalSuccessful + totalErrors;
    final allMakePercentage = totalWithResults > 0
        ? totalSuccessful / totalWithResults
        : 0.0;
    final allMissPercentage = totalWithResults > 0
        ? totalErrors / totalWithResults
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Add "All" bar first
              _buildBarChartBar(
                context,
                'all',
                allMakePercentage,
                allMissPercentage,
                totalMakes,
                totalErrors,
              ),
              // Then individual serve type bars
              ...servingResults.entries.map((entry) {
                final serveType = entry.key;
                final results = entry.value;
                final inCount = results['in'] ?? 0;
                final aceCount = results['ace'] ?? 0;
                final errorCount = results['error'] ?? 0;

                // Calculate actual percentages for this serve type (includes aces)
                final totalSuccessful = inCount + aceCount;
                final totalWithResults = totalSuccessful + errorCount;
                final makePercentage = totalWithResults > 0
                    ? totalSuccessful / totalWithResults
                    : 0.0;
                final missPercentage = totalWithResults > 0
                    ? errorCount / totalWithResults
                    : 0.0;

                return _buildBarChartBar(
                  context,
                  serveType,
                  makePercentage,
                  missPercentage,
                  inCount,
                  errorCount,
                );
              }).toList(),
            ],
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
    final labels = {
      'float': 'Float',
      'hybrid': 'Hybrid',
      'spin': 'Spin',
      'all': 'All',
    };

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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Makes count on the left
            SizedBox(
              width: 25,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inCount.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Show aces count below makes
                  Text(
                    '(${serveType == 'all' ? _getTotalAceCount() : _getAceCountForServeType(serveType)})',
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.setColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            // Bar chart
            SizedBox(
              height: 28,
              width: 120,
              child: _buildBarSegments(
                makePercentage,
                missPercentage,
                inCount,
                errorCount,
              ),
            ),
            const SizedBox(width: 5),
            // Misses count on the right
            SizedBox(
              width: 25,
              child: Text(
                errorCount.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.redError,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
        height: 28,
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
            color: AppColors.secondary,
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
            color: AppColors.redError,
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

    // Both have values, show split bar with minimum widths
    final minPercent = 20; // Minimum 20% width for readability
    final adjustedMakePercent = math.max(makePercent, minPercent);
    final adjustedMissPercent = math.max(missPercent, minPercent);

    return Row(
      children: [
        // Make percentage (green)
        Expanded(
          flex: adjustedMakePercent,
          child: Tooltip(
            message: 'Makes: ${makePercent}% ($inCount)',
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.secondary,
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
          flex: adjustedMissPercent,
          child: Tooltip(
            message: 'Misses: ${missPercent}% ($errorCount)',
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.redError,
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

  int _getAceCountForServeType(String serveType) {
    final serveEvents = widget.teamEvents
        .where((e) => e.type == EventType.serve)
        .toList();

    int aceCount = 0;
    for (final event in serveEvents) {
      final eventServeType = event.metadata['serveType'] as String?;
      final result = event.metadata['result'] as String?;

      if (eventServeType == serveType && result == 'ace') {
        aceCount++;
      }
    }

    return aceCount;
  }

  int _getTotalAceCount() {
    final serveEvents = widget.teamEvents
        .where((e) => e.type == EventType.serve)
        .toList();

    int totalAces = 0;
    for (final event in serveEvents) {
      final result = event.metadata['result'] as String?;

      if (result == 'ace') {
        totalAces++;
      }
    }

    return totalAces;
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
      'float': AppColors.primary,
      'hybrid': AppColors.hybridBlue,
      'spin': AppColors.spinBlue,
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
