import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/player.dart';
import '../models/event.dart';
import '../utils/passing_rating_gradient.dart';

class PassingHistogram extends StatelessWidget {
  final List<Player> practicePlayers;
  final List<Event> teamEvents;
  final Map<String, dynamic> Function(List<Event>) getPlayerPassingStats;

  const PassingHistogram({
    super.key,
    required this.practicePlayers,
    required this.teamEvents,
    required this.getPlayerPassingStats,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate total passing ratings across all players
    final totalRatings = <String, int>{
      'ace': 0,
      '0': 0,
      '1': 0,
      '2': 0,
      '3': 0,
    };

    for (final player in practicePlayers) {
      final playerEvents = teamEvents
          .where((e) => e.player.id == player.id)
          .toList();
      final passingStats = getPlayerPassingStats(playerEvents);

      totalRatings['ace'] =
          (totalRatings['ace'] ?? 0) + ((passingStats['ace'] ?? 0) as int);
      totalRatings['0'] =
          (totalRatings['0'] ?? 0) + ((passingStats['0'] ?? 0) as int);
      totalRatings['1'] =
          (totalRatings['1'] ?? 0) + ((passingStats['1'] ?? 0) as int);
      totalRatings['2'] =
          (totalRatings['2'] ?? 0) + ((passingStats['2'] ?? 0) as int);
      totalRatings['3'] =
          (totalRatings['3'] ?? 0) + ((passingStats['3'] ?? 0) as int);
    }

    final totalPasses = totalRatings.values.reduce((a, b) => a + b);
    if (totalPasses == 0) {
      return const SizedBox.shrink();
    }

    // Calculate team passing average
    final passingAverage = totalPasses > 0
        ? (totalRatings['ace']! * 3 +
                  totalRatings['3']! * 3 +
                  totalRatings['2']! * 2 +
                  totalRatings['1']! * 1 +
                  totalRatings['0']! * 0) /
              totalPasses
        : 0.0;

    final maxCount = totalRatings.values.reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Passing Ratings Distribution',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Total Passes: $totalPasses',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            // Team passing average as big number
            Text(
              passingAverage.toStringAsFixed(2),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: PassingRatingGradient.getColor(passingAverage),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IntrinsicWidth(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          _buildHistogramBar(
                            context,
                            'Ace',
                            totalRatings['ace']!,
                            maxCount,
                            totalPasses,
                            const Color(0xFF00E5FF),
                            isFirst: true,
                          ),
                          _buildHistogramBar(
                            context,
                            '0',
                            totalRatings['0']!,
                            maxCount,
                            totalPasses,
                            const Color(0xFF00B8D4),
                          ),
                          _buildHistogramBar(
                            context,
                            '1',
                            totalRatings['1']!,
                            maxCount,
                            totalPasses,
                            const Color(0xFF0097A7),
                          ),
                          _buildHistogramBar(
                            context,
                            '2',
                            totalRatings['2']!,
                            maxCount,
                            totalPasses,
                            const Color(0xFF006064),
                          ),
                          _buildHistogramBar(
                            context,
                            '3',
                            totalRatings['3']!,
                            maxCount,
                            totalPasses,
                            const Color(0xFF004D40),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistogramBar(
    BuildContext context,
    String label,
    int count,
    int maxCount,
    int totalPasses,
    Color color, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final percentage = totalPasses > 0 ? (count / totalPasses * 100) : 0.0;
    final height = maxCount > 0 ? (count / maxCount * 180) : 0.0;

    return Column(
      children: [
        const SizedBox(height: 2),
        SizedBox(
          width: 50,
          height: 180,
          child: Stack(
            children: [
              // Container without border
              Container(width: 50, height: 180),
              // Bar - always show at least a small bar for count = 0
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: height > 0 ? height : 2, // Show 2px bar for count = 0
                  decoration: BoxDecoration(color: color),
                ),
              ),
              // Number positioned on the colored bar
              Positioned(
                top: height > 0
                    ? 180 -
                          height +
                          5 // Position within the bar (5px from top of bar)
                    : 180 -
                          2 -
                          15, // Position above the small bar for zero counts
                left: 0,
                right: 0,
                child: Text(
                  count.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: height > 0
                        ? Colors.white
                        : Colors
                              .black, // White on colored bar, black above small bar
                    shadows: height > 0
                        ? [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ]
                        : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
