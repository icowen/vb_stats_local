import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/player.dart';
import '../models/event.dart';

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

    final maxCount = totalRatings.values.reduce(math.max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 4),
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
    final height = maxCount > 0 ? (count / maxCount * 120) : 0.0;

    return Column(
      children: [
        const SizedBox(height: 2),
        Container(
          width: 40,
          height: 120,
          decoration: BoxDecoration(
            border: Border(
              left: isFirst
                  ? BorderSide(color: Colors.grey[300]!)
                  : BorderSide.none,
              right: BorderSide(color: Colors.grey[300]!),
              top: BorderSide(color: Colors.grey[300]!),
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Stack(
            children: [
              if (height > 0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(color: color),
                  ),
                ),
              Positioned(
                top: height > 0 ? math.max(5, 120 - height - 15) : 100,
                left: 0,
                right: 0,
                child: Text(
                  count.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
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
