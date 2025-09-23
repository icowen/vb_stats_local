import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/practice.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../database_helper.dart';
import '../viz/passing_histogram.dart';
import '../viz/serving_pie_chart.dart';
import '../viz/attacking_bar_chart.dart';
import '../viz/player_stats_table.dart';

class PracticeAnalysisPage extends StatefulWidget {
  final Practice practice;

  const PracticeAnalysisPage({super.key, required this.practice});

  @override
  State<PracticeAnalysisPage> createState() => _PracticeAnalysisPageState();
}

class _PracticeAnalysisPageState extends State<PracticeAnalysisPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Player> _practicePlayers = [];
  List<Event> _teamEvents = [];
  bool _isLoading = true;

  String _formatHitPercentage(double hitPercentage) {
    if (hitPercentage >= 1.0) {
      return '1.000';
    } else {
      return '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTeamStats();
  }

  Future<void> _loadTeamStats() async {
    try {
      await _dbHelper.ensureTablesExist();
      final practicePlayers = await _dbHelper.getPracticePlayers(
        widget.practice.id!,
      );
      final teamEvents = await _dbHelper.getEventsForPractice(
        widget.practice.id!,
      );

      setState(() {
        _practicePlayers = practicePlayers;
        _teamEvents = teamEvents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading team stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Calculate optimal column widths based on content
  Map<String, double> _calculateColumnWidths() {
    Map<String, double> widths = {};

    // Player Info columns
    double maxPlayerNameLength = 'Player'.length.toDouble();
    double maxJerseyLength = 'Jersey'.length.toDouble();

    for (var player in _practicePlayers) {
      maxPlayerNameLength = math.max(
        maxPlayerNameLength,
        player.fullName.length.toDouble(),
      );
      maxJerseyLength = math.max(
        maxJerseyLength,
        player.jerseyDisplay.length.toDouble(),
      );
    }

    widths['Player'] = math.max(
      (maxPlayerNameLength * 8) + 16, // 8 pixels per character + padding
      40.0, // Minimum width
    );
    widths['Jersey'] = math.max(
      (maxJerseyLength * 8) + 16,
      40.0, // Minimum width
    );

    // Serving columns
    List<String> servingHeaders = [
      'Serves',
      'Aces',
      'In',
      'Errors',
      'Float',
      'Hybrid',
      'Spin',
    ];
    for (String header in servingHeaders) {
      double maxLength = header.length.toDouble();
      for (var player in _practicePlayers) {
        final playerEvents = _teamEvents
            .where((e) => e.player.id == player.id)
            .toList();
        final stats = _getPlayerServingStats(playerEvents);
        String value = '';
        switch (header) {
          case 'Serves':
            value = '${stats['total']}';
            break;
          case 'Aces':
            value = '${stats['ace'] ?? 0}';
            break;
          case 'In':
            value = '${stats['in']}';
            break;
          case 'Errors':
            value = '${stats['error']}';
            break;
          case 'Float':
            value = '${stats['float']}';
            break;
          case 'Hybrid':
            value = '${stats['hybrid']}';
            break;
          case 'Spin':
            value = '${stats['spin']}';
            break;
        }
        maxLength = math.max(maxLength, value.length.toDouble());
      }
      // Set minimum width
      double minWidth = 40.0; // Minimum width for all columns
      widths[header] = math.max((maxLength * 8) + 16, minWidth);
    }

    // Passing columns
    List<String> passingHeaders = [
      'Passes',
      'Average',
      'Ace',
      '0',
      '1',
      '2',
      '3',
    ];
    for (String header in passingHeaders) {
      double maxLength = header.length.toDouble();
      for (var player in _practicePlayers) {
        final playerEvents = _teamEvents
            .where((e) => e.player.id == player.id)
            .toList();
        final stats = _getPlayerPassingStats(playerEvents);
        String value = '';
        switch (header) {
          case 'Passes':
            value = '${stats['total']}';
            break;
          case 'Average':
            value = '${stats['average'].toStringAsFixed(2)}';
            break;
          case 'Ace':
            value = '${stats['ace']}';
            break;
          case '0':
            value = '${stats['0']}';
            break;
          case '1':
            value = '${stats['1']}';
            break;
          case '2':
            value = '${stats['2']}';
            break;
          case '3':
            value = '${stats['3']}';
            break;
        }
        maxLength = math.max(maxLength, value.length.toDouble());
      }
      // Set minimum width
      double minWidth = 40.0; // Minimum width for all columns
      widths[header] = math.max((maxLength * 8) + 16, minWidth);
    }

    // Attacking columns
    List<String> attackingHeaders = [
      'Attacks',
      'Kills',
      'In',
      'Errors',
      'Hit %',
    ];
    for (String header in attackingHeaders) {
      double maxLength = header.length.toDouble();
      for (var player in _practicePlayers) {
        final playerEvents = _teamEvents
            .where((e) => e.player.id == player.id)
            .toList();
        final stats = _getPlayerAttackingStats(playerEvents);
        String value = '';
        switch (header) {
          case 'Attacks':
            value = '${stats['total']}';
            break;
          case 'Kills':
            value = '${stats['kill']}';
            break;
          case 'In':
            value = '${stats['in']}';
            break;
          case 'Errors':
            value = '${stats['error']}';
            break;
          case 'Hit %':
            final total = stats['total'] as int;
            final kill = stats['kill'] as int;
            final error = stats['error'] as int;
            final hitPercentage = total > 0 ? (kill - error) / total : 0.0;
            value = _formatHitPercentage(hitPercentage);
            break;
        }
        maxLength = math.max(maxLength, value.length.toDouble());
      }
      // Set minimum width
      double minWidth = 40.0; // Minimum width for all columns
      widths[header] = math.max((maxLength * 8) + 16, minWidth);
    }

    return widths;
  }

  @override
  Widget build(BuildContext context) {
    final columnWidths = _calculateColumnWidths();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.practice.practiceTitle} - Team Stats'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : _practicePlayers.isEmpty
          ? const Center(
              child: Text(
                'No players in this practice.\nAdd players to see team stats.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHighlightsSection(),
                  const SizedBox(height: 24),

                  // Visualizations Row
                  SizedBox(
                    height: 350,
                    child: Row(
                      children: [
                        Expanded(
                          child: PassingHistogram(
                            practicePlayers: _practicePlayers,
                            teamEvents: _teamEvents,
                            getPlayerPassingStats: _getPlayerPassingStats,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ServingPieChart(
                            practicePlayers: _practicePlayers,
                            teamEvents: _teamEvents,
                            getPlayerServingStats: _getPlayerServingStats,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AttackingBarChart(
                            practicePlayers: _practicePlayers,
                            teamEvents: _teamEvents,
                            getPlayerAttackingStats: _getPlayerAttackingStats,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Player Stats Table
                  Text(
                    'Player Statistics',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _buildPlayerStatsTable(columnWidths),
                ],
              ),
            ),
    );
  }

  Widget _buildHighlightsSection() {
    final highlights = _calculateHighlights();

    return Row(
      children: [
        Expanded(
          child: _buildHighlightCard(
            'Best Passer',
            Icons.touch_app,
            highlights['bestPasser']!,
            '${highlights['bestPasserAvg']!.toStringAsFixed(2)} avg',
            const Color(0xFF00E5FF),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildHighlightCard(
            'Best Server',
            Icons.sports_volleyball,
            highlights['bestServer']!,
            '${highlights['bestServerAces']} aces',
            const Color(0xFF00FF88),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildHighlightCard(
            'Best Attacker',
            Icons.sports_handball,
            highlights['bestAttacker']!,
            '${highlights['bestAttackerKills']} kills',
            const Color(0xFFFF6B6B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildHighlightCard(
            'Most Efficient',
            Icons.trending_up,
            highlights['mostEfficient']!,
            '${_formatHitPercentage(highlights['bestHitPercentage']!)} hit %',
            const Color(0xFFFFFF00),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCard(
    String title,
    IconData icon,
    Player player,
    String stat,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              player.fullName,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              stat,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStatsTable(Map<String, double> columnWidths) {
    return PlayerStatsTable(
      columnWidths: columnWidths,
      teamPlayers: _practicePlayers,
      teamEvents: _teamEvents,
      getPlayerServingStats: _getPlayerServingStats,
      getPlayerPassingStats: _getPlayerPassingStats,
      getPlayerAttackingStats: _getPlayerAttackingStats,
    );
  }


  Map<String, dynamic> _calculateHighlights() {
    Player? bestPasser;
    double bestPasserAvg = 0.0;
    Player? bestServer;
    int bestServerAces = 0;
    Player? bestAttacker;
    int bestAttackerKills = 0;
    Player? mostEfficient;
    double bestHitPercentage = -1.0;

    for (final player in _practicePlayers) {
      final playerEvents = _teamEvents
          .where((e) => e.player.id == player.id)
          .toList();
      final servingStats = _getPlayerServingStats(playerEvents);
      final passingStats = _getPlayerPassingStats(playerEvents);
      final attackingStats = _getPlayerAttackingStats(playerEvents);

      // Best Passer (highest passing average)
      final passingAvg = passingStats['average'] as double;
      if (passingAvg > bestPasserAvg) {
        bestPasser = player;
        bestPasserAvg = passingAvg;
      }

      // Best Server (most aces)
      final aces = servingStats['ace'] ?? 0;
      if (aces > bestServerAces) {
        bestServer = player;
        bestServerAces = aces;
      }

      // Best Attacker (most kills)
      final kills = attackingStats['kill']!;
      if (kills > bestAttackerKills) {
        bestAttacker = player;
        bestAttackerKills = kills;
      }

      // Most Efficient (highest hit percentage)
      final hitPercentage = attackingStats['total']! > 0
          ? (attackingStats['kill']! - attackingStats['error']!) /
                attackingStats['total']!
          : 0.0;
      if (hitPercentage > bestHitPercentage) {
        mostEfficient = player;
        bestHitPercentage = hitPercentage;
      }
    }

    return {
      'bestPasser': bestPasser ?? _practicePlayers.first,
      'bestPasserAvg': bestPasserAvg,
      'bestServer': bestServer ?? _practicePlayers.first,
      'bestServerAces': bestServerAces,
      'bestAttacker': bestAttacker ?? _practicePlayers.first,
      'bestAttackerKills': bestAttackerKills,
      'mostEfficient': mostEfficient ?? _practicePlayers.first,
      'bestHitPercentage': bestHitPercentage,
    };
  }

  // Player-specific stats
  Map<String, int> _getPlayerServingStats(List<Event> playerEvents) {
    final serveEvents = playerEvents
        .where((e) => e.type == EventType.serve)
        .toList();
    final stats = <String, int>{
      'float': 0,
      'hybrid': 0,
      'spin': 0,
      'in': 0,
      'error': 0,
      'total': 0,
    };

    for (final event in serveEvents) {
      final serveType = event.metadata['serveType'] as String?;
      final result = event.metadata['result'] as String?;

      stats['total'] = (stats['total'] ?? 0) + 1;
      if (serveType != null) {
        stats[serveType] = (stats[serveType] ?? 0) + 1;
      }
      if (result != null) {
        stats[result] = (stats[result] ?? 0) + 1;
      }
    }

    return stats;
  }

  Map<String, dynamic> _getPlayerPassingStats(List<Event> playerEvents) {
    final passEvents = playerEvents
        .where((e) => e.type == EventType.pass)
        .toList();
    final stats = <String, dynamic>{
      'ace': 0,
      '0': 0,
      '1': 0,
      '2': 0,
      '3': 0,
      'total': 0,
    };

    for (final event in passEvents) {
      final rating = event.metadata['rating'] as String?;
      stats['total'] = (stats['total'] ?? 0) + 1;
      if (rating != null && stats.containsKey(rating)) {
        stats[rating] = (stats[rating] ?? 0) + 1;
      }
    }

    // Calculate average
    double totalPoints = 0;
    for (final event in passEvents) {
      final rating = event.metadata['rating'] as String?;
      switch (rating) {
        case 'ace':
          totalPoints += 0;
          break;
        case '3':
          totalPoints += 3;
          break;
        case '2':
          totalPoints += 2;
          break;
        case '1':
          totalPoints += 1;
          break;
        case '0':
          totalPoints += 0;
          break;
      }
    }

    final average = passEvents.isEmpty ? 0.0 : totalPoints / passEvents.length;
    stats['average'] = average;

    return stats;
  }

  Map<String, int> _getPlayerAttackingStats(List<Event> playerEvents) {
    final attackEvents = playerEvents
        .where((e) => e.type == EventType.attack)
        .toList();
    final stats = <String, int>{'kill': 0, 'in': 0, 'error': 0, 'total': 0};

    for (final event in attackEvents) {
      final result = event.metadata['result'] as String?;
      stats['total'] = (stats['total'] ?? 0) + 1;
      if (result != null && stats.containsKey(result)) {
        stats[result] = (stats[result] ?? 0) + 1;
      }
    }

    return stats;
  }
}
