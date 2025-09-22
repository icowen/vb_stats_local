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

    for (final player in practicePlayers) {
      final playerEvents = teamEvents
          .where((e) => e.player.id == player.id)
          .toList();
      final attackingStats = getPlayerAttackingStats(playerEvents);
      playerStats[player] = attackingStats;
      maxTotal = math.max(maxTotal, attackingStats['total'] ?? 0);
    }

    // Always show the chart, even if no attacks
    if (maxTotal == 0) {
      maxTotal = 1; // Set minimum height for empty bars
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attacking Attempts by Player',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: playerStats.entries.map((entry) {
                  final player = entry.key;
                  final stats = entry.value;
                  final total = stats['total'] ?? 0;
                  final kill = stats['kill'] ?? 0;
                  final inPlay = stats['in'] ?? 0;
                  final error = stats['error'] ?? 0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Column(
                        children: [
                          // Bar
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: total > 0
                                  ? Stack(
                                      children: [
                                        // Kill segment (top)
                                        if (kill > 0)
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            height: (kill / maxTotal) * 180,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00E5FF),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        4,
                                                      ),
                                                      topRight: Radius.circular(
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
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        shadows: [
                                                          Shadow(
                                                            offset:
                                                                const Offset(
                                                                  1,
                                                                  1,
                                                                ),
                                                            blurRadius: 2,
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.5,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        // In segment (middle)
                                        if (inPlay > 0)
                                          Positioned(
                                            top: (kill / maxTotal) * 180,
                                            left: 0,
                                            right: 0,
                                            height: (inPlay / maxTotal) * 180,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00B8D4),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  inPlay.toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        shadows: [
                                                          Shadow(
                                                            offset:
                                                                const Offset(
                                                                  1,
                                                                  1,
                                                                ),
                                                            blurRadius: 2,
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.5,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        // Error segment (bottom)
                                        if (error > 0)
                                          Positioned(
                                            top:
                                                ((kill + inPlay) / maxTotal) *
                                                180,
                                            left: 0,
                                            right: 0,
                                            height: (error / maxTotal) * 180,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0097A7),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      bottomLeft:
                                                          Radius.circular(4),
                                                      bottomRight:
                                                          Radius.circular(4),
                                                    ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  error.toString(),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        shadows: [
                                                          Shadow(
                                                            offset:
                                                                const Offset(
                                                                  1,
                                                                  1,
                                                                ),
                                                            blurRadius: 2,
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.5,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
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
                          const SizedBox(height: 8),
                          // Player name
                          Text(
                            player.firstName ?? 'Unknown',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Total attempts
                          Text(
                            'Total: $total',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(context, 'Kill', const Color(0xFF00E5FF)),
                const SizedBox(width: 16),
                _buildLegendItem(context, 'In', const Color(0xFF00B8D4)),
                const SizedBox(width: 16),
                _buildLegendItem(context, 'Error', const Color(0xFF0097A7)),
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
}
