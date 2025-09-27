import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/practice.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../database_helper.dart';
import '../services/player_service.dart';
import '../services/event_service.dart';
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
  final PlayerService _playerService = PlayerService();
  final EventService _eventService = EventService();
  List<Player> _practicePlayers = [];
  List<Event> _teamEvents = [];
  bool _isLoading = true;

  // Filter state
  EventType? _selectedActionType;
  Set<String> _selectedMetadata = {}; // Format: "key:value"
  Set<Player> _selectedPlayers = {};
  List<Event> _displayedEvents = [];

  String _formatHitPercentage(double hitPercentage) {
    if (hitPercentage >= 1.0) {
      return '1.000';
    } else {
      return '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';
    }
  }

  void _updateDisplayedEvents() {
    setState(() {
      if (_selectedActionType == null) {
        // If no action type selected, show nothing
        _displayedEvents = [];
      } else {
        // Filter events by selected action type, metadata, and players
        _displayedEvents = _teamEvents.where((event) {
          // Filter by action type
          if (event.type != _selectedActionType) {
            return false;
          }

          // Filter by metadata (if any metadata selected)
          if (_selectedMetadata.isNotEmpty) {
            // All selected metadata must match (AND logic)
            for (final metadataSelection in _selectedMetadata) {
              // Parse "key:value" format
              final parts = metadataSelection.split(':');
              if (parts.length == 2) {
                final key = parts[0];
                final value = parts[1];
                if (!event.metadata.containsKey(key) ||
                    event.metadata[key].toString() != value) {
                  return false; // This metadata doesn't match, exclude event
                }
              }
            }
          }

          // Filter by player (if any players selected)
          if (_selectedPlayers.isNotEmpty &&
              !_selectedPlayers.contains(event.player)) {
            return false;
          }

          return true;
        }).toList();
      }
    });
  }

  void _toggleActionType(EventType actionType) {
    setState(() {
      if (_selectedActionType == actionType) {
        // If the same action type is selected, deselect it
        _selectedActionType = null;
      } else {
        // Select the new action type
        _selectedActionType = actionType;
      }
      _selectedMetadata.clear(); // Clear metadata when changing action types
    });
    _updateDisplayedEvents();
  }

  void _toggleMetadata(String key, String value) {
    final metadataSelection = '$key:$value';
    setState(() {
      if (_selectedMetadata.contains(metadataSelection)) {
        _selectedMetadata.remove(metadataSelection);
      } else {
        _selectedMetadata.add(metadataSelection);
      }
    });
    _updateDisplayedEvents();
  }

  void _togglePlayer(Player player) {
    setState(() {
      if (_selectedPlayers.contains(player)) {
        _selectedPlayers.remove(player);
      } else {
        _selectedPlayers.add(player);
      }
    });
    _updateDisplayedEvents();
  }

  Map<String, Set<String>> _getAvailableMetadataGroups() {
    if (_selectedActionType == null) return {};

    final Map<String, Set<String>> metadataGroups = {};
    for (final event in _teamEvents) {
      if (event.type == _selectedActionType) {
        // Group metadata by key, collecting all values for each key
        for (final entry in event.metadata.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is String || value is bool) {
            metadataGroups.putIfAbsent(key, () => <String>{});
            metadataGroups[key]!.add(value.toString());
          }
        }
      }
    }

    // Sort the values within each group
    for (final key in metadataGroups.keys) {
      final sortedValues = metadataGroups[key]!.toList()..sort();
      metadataGroups[key] = sortedValues.toSet();
    }

    return metadataGroups;
  }

  Color _getActionTypeColor(EventType actionType) {
    switch (actionType) {
      case EventType.serve:
        return const Color(0xFF00E5FF); // Light blue
      case EventType.pass:
        return const Color(0xFF00FF88); // Light green
      case EventType.attack:
        return const Color(0xFFFF8800); // Orange
      case EventType.block:
        return const Color(0xFF9C27B0); // Purple
      case EventType.dig:
        return const Color(0xFFFF4444); // Red
      case EventType.set:
        return const Color(0xFFFFFF00); // Yellow
      case EventType.freeball:
        return const Color(0xFF00FF00); // Bright green
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
      final practicePlayers = await _playerService.getPracticePlayers(
        widget.practice.id!,
      );
      final teamEvents = await _eventService.getEventsForPractice(
        widget.practice.id!,
      );

      setState(() {
        _practicePlayers = practicePlayers;
        _teamEvents = teamEvents;
        _displayedEvents =
            []; // Initially show nothing until action types are selected
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

                  // Court Visualization Section
                  _buildCourtVisualizationSection(),
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

  Widget _buildCourtVisualizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Court Visualization',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),

        // Filters and Court Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Filters
            Expanded(
              flex: 2,
              child: _buildFiltersSection(),
            ),
            const SizedBox(width: 16),
            // Right side - Court
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 360, // Reduced height to match court proportions
                    child: _buildMultiEventCourt(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_displayedEvents.length} events displayed',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Type and Metadata Filters
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
                'Action Type:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: EventType.values.map((actionType) {
                  final isSelected = _selectedActionType == actionType;
                  final color = _getActionTypeColor(actionType);
                  return OutlinedButton(
                    onPressed: () => _toggleActionType(actionType),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isSelected ? color : Colors.grey[600],
                      backgroundColor: isSelected
                          ? color.withOpacity(0.2)
                          : Colors.transparent,
                      side: BorderSide(
                        color: isSelected ? color : color.withOpacity(0.5),
                        width: isSelected ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(
                      actionType.displayName,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Metadata Filters
              if (_selectedActionType != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: _getAvailableMetadataGroups().entries.map((entry) {
                    final groupName = entry.key;
                    final values = entry.value.toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          groupName.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: values.map((value) {
                            final isSelected = _selectedMetadata.contains(
                              '$groupName:$value',
                            );
                            return OutlinedButton(
                              onPressed: () =>
                                  _toggleMetadata(groupName, value),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isSelected
                                    ? const Color(0xFF00FF88)
                                    : Colors.grey[600],
                                backgroundColor: isSelected
                                    ? const Color(0xFF00FF88).withOpacity(0.2)
                                    : Colors.transparent,
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF00FF88)
                                      : const Color(
                                          0xFF00FF88,
                                        ).withOpacity(0.5),
                                  width: isSelected ? 2 : 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                minimumSize: const Size(0, 28),
                              ),
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ],
          ),

        const SizedBox(height: 16),

        // Player Selection
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
                'Players:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Player Selection Button
              GestureDetector(
                onTap: () => _showPlayerSelectionModal(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select Players (${_selectedPlayers.length} selected)',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      Icon(Icons.person_add, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),

              // Selected Players Tiles (below the button)
              if (_selectedPlayers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _selectedPlayers.map((player) {
                    return GestureDetector(
                      onTap: () => _togglePlayer(player),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              player.fullName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
          ],
        ),
      ],
    );
  }

  void _showPlayerSelectionModal() {
    // Create a copy of the current selection for the modal
    Set<Player> tempSelectedPlayers = Set.from(_selectedPlayers);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Select Players'),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // Players List
                    Expanded(
                      child: ListView.builder(
                        itemCount: _practicePlayers.length,
                        itemBuilder: (context, index) {
                          final player = _practicePlayers[index];
                          final isSelected = tempSelectedPlayers.contains(
                            player,
                          );

                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: isSelected
                                  ? Colors.blue[600]
                                  : Colors.grey[400],
                            ),
                            title: Text(
                              player.fullName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.blue[700]
                                    : Colors.grey[700],
                              ),
                            ),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  tempSelectedPlayers.remove(player);
                                } else {
                                  tempSelectedPlayers.add(player);
                                }
                              });
                            },
                            selected: isSelected,
                            selectedTileColor: Colors.blue.withOpacity(0.1),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    // Apply the changes when Done is pressed
                    setState(() {
                      _selectedPlayers = tempSelectedPlayers;
                    });
                    _updateDisplayedEvents();
                    Navigator.of(context).pop();
                  },
                  child: Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMultiEventCourt() {
    return SizedBox(
      width: double.infinity,
      height: 360, // Reduced height to match container
      child: CustomPaint(
        painter: _MultiEventCourtPainter(events: _displayedEvents),
      ),
    );
  }
}

class _MultiEventCourtPainter extends CustomPainter {
  final List<Event> events;

  _MultiEventCourtPainter({required this.events});

  @override
  void paint(Canvas canvas, Size size) {
    final outerPaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.fill;

    final outerLinePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final courtLinePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final netPaint = Paint()
      ..color = const Color(0xFF9C27B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Calculate court position (centered within outer border)
    final courtSize = 480.0;
    final courtHeight = 240.0;
    final courtOffsetX = (size.width - courtSize) / 2;
    // Use equal spacing all around the court
    final spacingX = (size.width - courtSize) / 2;
    final spacingY = (size.height - courtHeight) / 2;
    final equalSpacing = spacingX < spacingY ? spacingX : spacingY;
    final courtOffsetY = equalSpacing;

    // Draw outer border background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), outerPaint);

    // Draw outer border lines
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), outerLinePaint);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      outerLinePaint,
    );
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), outerLinePaint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      outerLinePaint,
    );

    // Draw court background
    canvas.drawRect(
      Rect.fromLTWH(courtOffsetX, courtOffsetY, courtSize, courtHeight),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..style = PaintingStyle.fill,
    );

    // Draw court sidelines
    canvas.drawLine(
      Offset(courtOffsetX, courtOffsetY),
      Offset(courtOffsetX + courtSize, courtOffsetY),
      courtLinePaint,
    );
    canvas.drawLine(
      Offset(courtOffsetX, courtOffsetY + courtHeight),
      Offset(courtOffsetX + courtSize, courtOffsetY + courtHeight),
      courtLinePaint,
    );

    // Draw court endlines
    canvas.drawLine(
      Offset(courtOffsetX, courtOffsetY),
      Offset(courtOffsetX, courtOffsetY + courtHeight),
      courtLinePaint,
    );
    canvas.drawLine(
      Offset(courtOffsetX + courtSize, courtOffsetY),
      Offset(courtOffsetX + courtSize, courtOffsetY + courtHeight),
      courtLinePaint,
    );

    // Draw net line
    final courtCenterX = courtOffsetX + courtSize / 2;
    canvas.drawLine(
      Offset(courtCenterX, courtOffsetY),
      Offset(courtCenterX, courtOffsetY + courtHeight),
      netPaint,
    );

    // Draw 10-foot attack lines
    final attackLinePaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final leftAttackLineX = courtCenterX - 80; // 80 pixels = 10 feet
    final rightAttackLineX = courtCenterX + 80;

    canvas.drawLine(
      Offset(leftAttackLineX, courtOffsetY - 5),
      Offset(leftAttackLineX, courtOffsetY + courtHeight + 5),
      attackLinePaint,
    );
    canvas.drawLine(
      Offset(rightAttackLineX, courtOffsetY - 5),
      Offset(rightAttackLineX, courtOffsetY + courtHeight + 5),
      attackLinePaint,
    );

    // Draw events
    for (final event in events) {
      if (event.fromX != null && event.fromY != null) {
        final eventColor = _getEventColor(event);
        final x = courtOffsetX + (event.fromX! * courtSize);
        final y = courtOffsetY + (event.fromY! * courtHeight);

        // Draw start point
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()
            ..color = eventColor
            ..style = PaintingStyle.fill,
        );

        // Draw end point if available
        if (event.toX != null && event.toY != null) {
          final endX = courtOffsetX + (event.toX! * courtSize);
          final endY = courtOffsetY + (event.toY! * courtHeight);

          canvas.drawCircle(
            Offset(endX, endY),
            3,
            Paint()
              ..color = eventColor.withOpacity(0.7)
              ..style = PaintingStyle.fill,
          );

          // Draw line connecting start and end
          canvas.drawLine(
            Offset(x, y),
            Offset(endX, endY),
            Paint()
              ..color = eventColor.withOpacity(0.5)
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  Color _getEventColor(Event event) {
    switch (event.type) {
      case EventType.serve:
        return const Color(0xFF00E5FF); // Light blue
      case EventType.pass:
        return const Color(0xFF00FF88); // Light green
      case EventType.attack:
        return const Color(0xFFFF8800); // Orange
      case EventType.block:
        return const Color(0xFF9C27B0); // Purple
      case EventType.dig:
        return const Color(0xFFFF4444); // Red
      case EventType.set:
        return const Color(0xFFFFFF00); // Yellow
      case EventType.freeball:
        return const Color(0xFF00FF00); // Bright green
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _MultiEventCourtPainter &&
        oldDelegate.events != events;
  }
}
