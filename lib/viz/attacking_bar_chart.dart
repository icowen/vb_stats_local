import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/player.dart';
import '../models/event.dart';

class AttackingBarChart extends StatelessWidget {
  final List<Player> practicePlayers;
  final List<Event> teamEvents;
  final Function(List<Event>) getPlayerAttackingStats;

  const AttackingBarChart({
    super.key,
    required this.practicePlayers,
    required this.teamEvents,
    required this.getPlayerAttackingStats,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate attacking stats for each player
    final playerStats = <Player, Map<String, int>>{};
    int maxTotal = 0;
    int totalKills = 0;
    int totalErrors = 0;
    int totalAttempts = 0;

    for (final player in practicePlayers) {
      final playerEvents = teamEvents
          .where((e) => e.player.id == player.id)
          .toList();
      final attackingStats = getPlayerAttackingStats(playerEvents);
      playerStats[player] = attackingStats;
      maxTotal = math.max(maxTotal, attackingStats['total'] ?? 0);

      // Add to totals
      totalKills += (attackingStats['kill'] ?? 0) as int;
      totalErrors += (attackingStats['error'] ?? 0) as int;
      totalAttempts += (attackingStats['total'] ?? 0) as int;
    }

    // Filter out players with no attempts and sort by hitting percentage (best to worst)
    final playersWithAttempts =
        playerStats.entries
            .where((entry) => (entry.value['total'] ?? 0) > 0)
            .toList()
          ..sort((a, b) {
            final aTotal = a.value['total'] ?? 0;
            final bTotal = b.value['total'] ?? 0;
            final aKills = a.value['kill'] ?? 0;
            final bKills = b.value['kill'] ?? 0;

            // Calculate hitting percentages
            final aHitPercentage = aTotal > 0 ? aKills / aTotal : 0.0;
            final bHitPercentage = bTotal > 0 ? bKills / bTotal : 0.0;

            // Sort by hitting percentage (descending - best to worst)
            return bHitPercentage.compareTo(aHitPercentage);
          });

    // If no players have attempts, show empty state
    if (playersWithAttempts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attacking Attempts by Player',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: Center(
                  child: Text(
                    'No attacking attempts recorded',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Always show the chart, even if no attacks
    if (maxTotal == 0) {
      maxTotal = 1; // Set minimum height for empty bars
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Attacking Attempts by Player',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Totals row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTotalStat(
                  context,
                  'Kills',
                  totalKills,
                  const Color(0xFF00FF88),
                ),
                _buildTotalStat(
                  context,
                  'Errors',
                  totalErrors,
                  const Color(0xFFFF4444),
                ),
                _buildTotalStat(
                  context,
                  'Attempts',
                  totalAttempts,
                  const Color(0xFF00E5FF),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: playersWithAttempts.map((entry) {
                        final player = entry.key;
                        final stats = entry.value;
                        final total = stats['total'] ?? 0;
                        final kill = stats['kill'] ?? 0;
                        final inPlay = stats['in'] ?? 0;
                        final error = stats['error'] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              // Player name and total
                              SizedBox(
                                width: 80,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      player.firstName ?? 'Unknown',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _formatHitPercentage(
                                        total > 0 ? (kill / total) : 0.0,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Bar
                              SizedBox(
                                width: 250,
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: total > 0
                                      ? ClipRect(
                                          child: SizedBox(
                                            width: 250,
                                            child: Builder(
                                              builder: (context) {
                                                // Calculate the actual bar width (scaled to maxTotal)
                                                // Subtract 2px for left and right borders
                                                final barWidth =
                                                    (total / maxTotal) * 248;
                                                return Row(
                                                  children: [
                                                    // Kill segment (left)
                                                    if (kill > 0)
                                                      Container(
                                                        width:
                                                            (kill / total) *
                                                            barWidth,
                                                        height: 24,
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFF00FF88,
                                                          ),
                                                          borderRadius:
                                                              const BorderRadius.only(
                                                                topLeft:
                                                                    Radius.circular(
                                                                      4,
                                                                    ),
                                                                bottomLeft:
                                                                    Radius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            kill.toString(),
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: Colors
                                                                      .black,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    // In segment (middle)
                                                    if (inPlay > 0)
                                                      Container(
                                                        width:
                                                            (inPlay / total) *
                                                            barWidth,
                                                        height: 24,
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  const Color(
                                                                    0xFF00E5FF,
                                                                  ),
                                                            ),
                                                        child: Center(
                                                          child: Text(
                                                            inPlay.toString(),
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: Colors
                                                                      .black,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    // Error segment (right)
                                                    if (error > 0)
                                                      Container(
                                                        width:
                                                            (error / total) *
                                                            barWidth,
                                                        height: 24,
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFFF4444,
                                                          ),
                                                          borderRadius:
                                                              const BorderRadius.only(
                                                                topRight:
                                                                    Radius.circular(
                                                                      4,
                                                                    ),
                                                                bottomRight:
                                                                    Radius.circular(
                                                                      4,
                                                                    ),
                                                              ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            error.toString(),
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  shadows: [
                                                                    Shadow(
                                                                      offset:
                                                                          const Offset(
                                                                            1,
                                                                            1,
                                                                          ),
                                                                      blurRadius:
                                                                          2,
                                                                      color: Colors
                                                                          .black
                                                                          .withOpacity(
                                                                            0.5,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            '0',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(context, 'Kill', const Color(0xFF00FF88)),
                const SizedBox(width: 16),
                _buildLegendItem(context, 'In', const Color(0xFF00E5FF)),
                const SizedBox(width: 16),
                _buildLegendItem(context, 'Error', const Color(0xFFFF4444)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildTotalStat(
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

  String _formatHitPercentage(double hitPercentage) {
    if (hitPercentage >= 1.0) {
      return '1.000';
    } else {
      return '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';
    }
  }
}
