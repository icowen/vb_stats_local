import 'package:flutter/material.dart';
import 'models/practice.dart';
import 'models/player.dart';
import 'models/event.dart';
import 'models/team.dart';
import 'database_helper.dart';
import 'team_stats_page.dart';
import 'team_stats_table.dart';
import 'widgets/stats_section.dart';
import 'utils/date_utils.dart';

enum UndoActionType { create, delete, update }

class UndoAction {
  final UndoActionType type;
  final Event? originalEvent;
  final Event? updatedEvent;
  final String description;

  UndoAction({
    required this.type,
    this.originalEvent,
    this.updatedEvent,
    required this.description,
  });
}

class PracticeStatsPage extends StatefulWidget {
  final Practice practice;

  const PracticeStatsPage({super.key, required this.practice});

  @override
  State<PracticeStatsPage> createState() => _PracticeStatsPageState();
}

class _PracticeStatsPageState extends State<PracticeStatsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Player> _teamPlayers = [];
  List<Player> _allPlayers = [];
  Player? _selectedPlayer;
  bool _isLoading = true;
  List<Event> _playerEvents = [];
  List<Event> _teamEvents = [];
  String? _selectedServeType;
  bool _isLoadingPlayerStats = false;

  // Caching system
  Map<int, List<Event>> _playerEventsCache = {};
  bool _cacheInitialized = false;

  // Undo/Redo system
  List<UndoAction> _undoStack = [];
  List<UndoAction> _redoStack = [];
  static const int maxUndoActions = 20;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      await _dbHelper.ensureTablesExist();
      await _loadTeamPlayers();
    } catch (e) {
      print('Error initializing database: $e');
      setState(() {
        _teamPlayers = [];
        _allPlayers = [];
        _teamEvents = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTeamPlayers() async {
    try {
      final practicePlayers = await _dbHelper.getPracticePlayers(
        widget.practice.id!,
      );
      final allPlayers = await _dbHelper.getAllPlayers();
      final teamEvents = await _dbHelper.getEventsForPractice(
        widget.practice.id!,
      );

      print(
        'Practice ${widget.practice.id} has ${practicePlayers.length} players',
      );
      for (final player in practicePlayers) {
        print('  - ${player.fullName} (ID: ${player.id})');
      }

      setState(() {
        _teamPlayers = practicePlayers;
        _allPlayers = allPlayers;
        _teamEvents = teamEvents;
        _isLoading = false;
      });

      // Initialize cache for all team players
      await _initializePlayerCache();
    } catch (e) {
      print('Error loading practice players: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('${widget.practice.team.teamName} Practice'),
        actions: [
          if (_undoStack.isNotEmpty)
            IconButton(
              onPressed: _undoLastAction,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo ${_undoStack.last.description}',
            ),
          IconButton(
            onPressed: () => _showStatsOptions(context),
            icon: const Icon(Icons.analytics),
            tooltip: 'Stats Options',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : Row(
              children: [
                // Left Sidebar - Players List (25%)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(
                        right: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Practice Info Header
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.fitness_center,
                                color: Color(0xFF00FF88),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.practice.practiceTitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    Text(
                                      DateFormatter.formatDate(
                                        widget.practice.date,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add Player and Team Buttons
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _addPlayerToPractice,
                                  icon: const Icon(Icons.person_add, size: 16),
                                  label: const Text(
                                    'Add Player',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00E5FF),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _addTeamToPractice,
                                  icon: const Icon(Icons.group_add, size: 16),
                                  label: const Text(
                                    'Add Team',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00FF88),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Players List
                        Expanded(
                          child: _teamPlayers.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'No players yet.\nTap "Add Player" to start.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 2.2,
                                        crossAxisSpacing: 4,
                                        mainAxisSpacing: 2,
                                      ),
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _teamPlayers.length,
                                  itemBuilder: (context, index) {
                                    final player = _teamPlayers[index];
                                    final isSelected =
                                        _selectedPlayer?.id == player.id;
                                    return Container(
                                      margin: EdgeInsets.zero,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF00E5FF,
                                              ).withOpacity(0.1)
                                            : null,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF00E5FF)
                                              : Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: InkWell(
                                        onTap: () => _selectPlayer(player),
                                        onLongPress: () =>
                                            _showRemovePlayerModal(player),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: double.infinity,
                                          height: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              // Jersey number and first name on one line
                                              Text(
                                                player.jerseyNumber != null
                                                    ? '${player.jerseyDisplay} ${player.firstName ?? ''}'
                                                    : player.firstName ?? '',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? const Color(0xFF00E5FF)
                                                      : null,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              // Last name on second line
                                              Text(
                                                player.lastName ?? '',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? const Color(0xFF00E5FF)
                                                      : null,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Middle - Stats Collection (50%)
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(
                        right: BorderSide(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildPlayerStatsArea(),
                    ),
                  ),
                ),
                // Right Side - Events History (25%)
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildEventsHistory(),
                  ),
                ),
              ],
            ),
    );
  }

  void _showStatsOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Stats Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.analytics, color: Color(0xFF00E5FF)),
                title: const Text('View Team Stats'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showTeamStats();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Color(0xFF00FF88)),
                title: const Text('Export Stats'),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportStats();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.grey),
                title: const Text('Practice Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPracticeSettings();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showTeamStats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TeamStatsPage(practice: widget.practice),
      ),
    );
  }

  void _exportStats() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality will be implemented here.'),
        backgroundColor: Color(0xFF00E5FF),
      ),
    );
  }

  void _showPracticeSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Practice Settings'),
          content: const Text('Practice configuration options will be here.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializePlayerCache() async {
    if (_cacheInitialized) return;

    try {
      // Pre-load events for all team players
      for (final player in _teamPlayers) {
        if (player.id != null) {
          final events = await _dbHelper.getEventsForPlayer(player.id!);
          _playerEventsCache[player.id!] = events;
        }
      }
      _cacheInitialized = true;
      print('Player cache initialized for ${_teamPlayers.length} players');
    } catch (e) {
      print('Error initializing player cache: $e');
    }
  }

  void _selectPlayer(Player player) async {
    if (_selectedPlayer?.id == player.id) {
      // If clicking the same player, unselect them
      setState(() {
        _selectedPlayer = null;
        _playerEvents = [];
        _selectedServeType = null; // Clear serve type selection
        _isLoadingPlayerStats = false;
      });
    } else {
      // Select the new player
      setState(() {
        _selectedPlayer = player;
        _selectedServeType = null; // Clear serve type selection
        _isLoadingPlayerStats = true;
      });

      // Use cache if available, otherwise load from database
      if (player.id != null && _playerEventsCache.containsKey(player.id!)) {
        _playerEvents = _playerEventsCache[player.id!]!;
        setState(() {
          _isLoadingPlayerStats = false;
        });
      } else {
        await _loadPlayerEvents();
        setState(() {
          _isLoadingPlayerStats = false;
        });
      }
    }
  }

  Future<void> _loadPlayerEvents() async {
    if (_selectedPlayer == null) return;

    try {
      final events = await _dbHelper.getEventsForPlayer(_selectedPlayer!.id!);
      _playerEvents = events;

      // Update cache
      if (_selectedPlayer!.id != null) {
        _playerEventsCache[_selectedPlayer!.id!] = events;
      }
    } catch (e) {
      print('Error loading player events: $e');
      _playerEvents = [];
    }
  }

  Future<void> _updatePlayerCache(int playerId) async {
    try {
      final events = await _dbHelper.getEventsForPlayer(playerId);
      _playerEventsCache[playerId] = events;
    } catch (e) {
      print('Error updating player cache for player $playerId: $e');
    }
  }

  Future<void> _loadTeamEvents() async {
    try {
      final events = await _dbHelper.getEventsForPractice(widget.practice.id!);
      setState(() {
        _teamEvents = events;
      });
    } catch (e) {
      print('Error loading team events: $e');
      setState(() {
        _teamEvents = [];
      });
    }
  }

  void _addPlayerToPractice() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Player to Practice'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: ListView.builder(
              itemCount: _allPlayers.length,
              itemBuilder: (context, index) {
                final player = _allPlayers[index];
                final isAlreadyAdded = _teamPlayers.any(
                  (p) => p.id == player.id,
                );
                return ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF00E5FF)),
                  title: Text(player.fullName),
                  subtitle: Text(player.jerseyDisplay),
                  trailing: isAlreadyAdded
                      ? const Icon(Icons.check, color: Colors.green)
                      : const Icon(Icons.add, color: Color(0xFF00FF88)),
                  onTap: isAlreadyAdded
                      ? null
                      : () async {
                          try {
                            // Add player to practice in database
                            await _dbHelper.addPlayerToPractice(
                              widget.practice.id!,
                              player.id!,
                            );

                            // Update local state
                            setState(() {
                              _teamPlayers.add(player);
                            });

                            Navigator.of(context).pop();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${player.fullName} added to practice',
                                  ),
                                  backgroundColor: const Color(0xFF00FF88),
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error adding player to practice: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding player: $e'),
                                  backgroundColor: const Color(0xFFFF4444),
                                ),
                              );
                            }
                          }
                        },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showRemovePlayerModal(Player player) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Player'),
          content: Text(
            'Are you sure you want to remove ${player.fullName} from this practice?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removePlayerFromPractice(player);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  void _addTeamToPractice() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<List<Team>>(
          future: _dbHelper.getAllTeams(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Error'),
                content: Text('Error loading teams: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final teams = snapshot.data ?? [];
            if (teams.isEmpty) {
              return AlertDialog(
                title: const Text('No Teams'),
                content: const Text('No teams available. Create a team first.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Add Team to Practice'),
              content: SizedBox(
                width: 300,
                height: 400,
                child: ListView.builder(
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.group,
                        color: Color(0xFF00FF88),
                      ),
                      title: Text(team.teamName),
                      subtitle: Text('${team.clubName} - ${team.age}U'),
                      trailing: const Icon(Icons.add, color: Color(0xFF00E5FF)),
                      onTap: () async {
                        try {
                          // Get all players from the team using the new teamId field
                          final allPlayers = await _dbHelper.getAllPlayers();
                          final teamPlayers = allPlayers
                              .where((player) => player.teamId == team.id)
                              .toList();

                          // Filter out players already in the practice
                          final currentPlayerIds = _teamPlayers
                              .map((p) => p.id)
                              .toSet();
                          final newPlayers = teamPlayers
                              .where(
                                (player) =>
                                    !currentPlayerIds.contains(player.id),
                              )
                              .toList();

                          print(
                            'Found ${teamPlayers.length} players in team ${team.teamName}, ${newPlayers.length} new players to add to practice ${widget.practice.id}',
                          );

                          if (newPlayers.isEmpty) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'All players from ${team.teamName} are already in this practice',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          // Add each new player to the practice
                          for (final player in newPlayers) {
                            print(
                              'Adding player ${player.fullName} to practice',
                            );
                            await _dbHelper.addPlayerToPractice(
                              widget.practice.id!,
                              player.id!,
                            );
                          }

                          // Update local state
                          setState(() {
                            _teamPlayers.addAll(newPlayers);
                          });

                          // Update cache for new players
                          for (final player in newPlayers) {
                            if (player.id != null) {
                              await _updatePlayerCache(player.id!);
                            }
                          }

                          print(
                            'Successfully added ${newPlayers.length} players to practice',
                          );

                          Navigator.of(context).pop();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${teamPlayers.length} players from ${team.teamName} added to practice',
                                ),
                                backgroundColor: const Color(0xFF00FF88),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error adding team to practice: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error adding team: $e'),
                                backgroundColor: const Color(0xFFFF4444),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removePlayerFromPractice(Player player) async {
    try {
      // Remove player from practice in database
      await _dbHelper.removePlayerFromPractice(widget.practice.id!, player.id!);

      // Update local state
      setState(() {
        _teamPlayers.removeWhere((p) => p.id == player.id);
        if (_selectedPlayer?.id == player.id) {
          _selectedPlayer = null;
          _playerEvents = [];
        }
      });

      // Remove from cache
      if (player.id != null) {
        _playerEventsCache.remove(player.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${player.fullName} removed from practice'),
            backgroundColor: const Color(0xFFFF8800),
          ),
        );
      }
    } catch (e) {
      print('Error removing player from practice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing player: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    }
  }

  Widget _buildPlayerStatsArea() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Groups (always show)
          _buildServingStats(),
          const SizedBox(height: 8),
          _buildPassingStats(),
          const SizedBox(height: 8),
          _buildAttackingStats(),
          const SizedBox(height: 16),
          // Team Stats Table
          Text(
            'Team Statistics',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTeamStatsTable(),
        ],
      ),
    );
  }

  Widget _buildEventsHistory() {
    // Sort events by timestamp (newest first)
    final sortedEvents = List<Event>.from(_teamEvents)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with undo/redo buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Events History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _undoStack.isNotEmpty ? _undoLastAction : null,
                  icon: const Icon(Icons.undo),
                  tooltip: _undoStack.isNotEmpty
                      ? 'Undo ${_undoStack.last.description}'
                      : 'Nothing to undo',
                  iconSize: 20,
                ),
                IconButton(
                  onPressed: _canRedo() ? _redoLastAction : null,
                  icon: const Icon(Icons.redo),
                  tooltip: _canRedo()
                      ? 'Redo last undone action'
                      : 'Nothing to redo',
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${sortedEvents.length} events recorded',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: sortedEvents.isEmpty
              ? const Center(
                  child: Text(
                    'No events recorded yet.\nStart recording stats to see them here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: sortedEvents.length,
                  itemBuilder: (context, index) {
                    final event = sortedEvents[index];
                    return _buildEventItem(event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventItem(Event event) {
    final time = event.timestamp;
    final timeString =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    String eventDescription = '';
    Color eventColor = Colors.grey;
    IconData eventIcon = Icons.circle;

    switch (event.type) {
      case EventType.serve:
        final result = event.metadata['result'] as String?;
        final serveType = event.metadata['serveType'] as String?;
        eventDescription =
            '${serveType ?? 'Unknown'} serve: ${result ?? 'Unknown'}';
        eventColor = result == 'ace'
            ? const Color(0xFF00FF88)
            : result == 'in'
            ? const Color(0xFF00E5FF)
            : const Color(0xFFFF4444);
        eventIcon = Icons.sports_volleyball;
        break;
      case EventType.pass:
        final rating = event.metadata['rating'] as String?;
        eventDescription = 'Pass rating: ${rating ?? 'Unknown'}';
        eventColor = rating == 'ace' || rating == '3'
            ? const Color(0xFF00FF88)
            : rating == '2'
            ? const Color(0xFF00E5FF)
            : rating == '1'
            ? const Color(0xFFFF8800)
            : const Color(0xFFFF4444);
        eventIcon = Icons.handshake;
        break;
      case EventType.attack:
        final result = event.metadata['result'] as String?;
        eventDescription = 'Attack: ${result ?? 'Unknown'}';
        eventColor = result == 'kill'
            ? const Color(0xFF00FF88)
            : result == 'in'
            ? const Color(0xFF00E5FF)
            : const Color(0xFFFF4444);
        eventIcon = Icons.sports;
        break;
      default:
        eventDescription = '${event.type.displayName} event';
        eventColor = Colors.grey;
        eventIcon = Icons.circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onLongPress: () => _showEventOptionsModal(event),
        child: ListTile(
          dense: true,
          leading: Icon(eventIcon, color: eventColor, size: 20),
          title: Text(
            event.player.fullName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            eventDescription,
            style: TextStyle(fontSize: 12, color: eventColor),
          ),
          trailing: Text(
            timeString,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  void _showEventOptionsModal(Event event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Event Options',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Player: ${event.player.fullName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Type: ${event.type.displayName}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Time: ${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEditEventModal(event);
              },
              child: const Text(
                'Edit',
                style: TextStyle(color: Color(0xFF00E5FF)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteEvent(event);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFFF4444)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditEventModal(Event event) {
    // Initialize form values based on event type
    String selectedEventType = event.type.name;
    Player selectedPlayer = event.player;
    Map<String, dynamic> formData = Map.from(event.metadata);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                'Edit Event',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Player Selection
                    Text(
                      'Player',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Player>(
                      value: selectedPlayer,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _teamPlayers.map((player) {
                        return DropdownMenuItem(
                          value: player,
                          child: Text(player.fullName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedPlayer = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Event Type Selection
                    Text(
                      'Event Type',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedEventType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: EventType.values.map((type) {
                        return DropdownMenuItem(
                          value: type.name,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedEventType = value!;
                          formData.clear(); // Clear form data when type changes
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dynamic form based on event type
                    _buildEventTypeForm(
                      selectedEventType,
                      formData,
                      setModalState,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _saveEditedEvent(
                    context,
                    event,
                    selectedPlayer,
                    selectedEventType,
                    formData,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEventTypeForm(
    String eventType,
    Map<String, dynamic> formData,
    StateSetter setModalState,
  ) {
    switch (eventType) {
      case 'serve':
        return _buildServeForm(formData, setModalState);
      case 'pass':
        return _buildPassForm(formData, setModalState);
      case 'attack':
        return _buildAttackForm(formData, setModalState);
      default:
        return const Text('Unknown event type');
    }
  }

  Widget _buildServeForm(
    Map<String, dynamic> formData,
    StateSetter setModalState,
  ) {
    final serveType = formData['serveType'] as String? ?? 'float';
    final result = formData['result'] as String? ?? 'in';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Serve Type
        Text('Serve Type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                'Float',
                'float',
                serveType == 'float',
                () => setModalState(() => formData['serveType'] = 'float'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'Hybrid',
                'hybrid',
                serveType == 'hybrid',
                () => setModalState(() => formData['serveType'] = 'hybrid'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'Spin',
                'spin',
                serveType == 'spin',
                () => setModalState(() => formData['serveType'] = 'spin'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Serve Result
        Text('Result', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                'Ace',
                'ace',
                result == 'ace',
                () => setModalState(() => formData['result'] = 'ace'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'In',
                'in',
                result == 'in',
                () => setModalState(() => formData['result'] = 'in'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'Error',
                'error',
                result == 'error',
                () => setModalState(() => formData['result'] = 'error'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPassForm(
    Map<String, dynamic> formData,
    StateSetter setModalState,
  ) {
    final rating = formData['rating'] as String? ?? '2';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pass Rating', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                'Ace',
                'ace',
                rating == 'ace',
                () => setModalState(() => formData['rating'] = 'ace'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                '0',
                '0',
                rating == '0',
                () => setModalState(() => formData['rating'] = '0'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                '1',
                '1',
                rating == '1',
                () => setModalState(() => formData['rating'] = '1'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                '2',
                '2',
                rating == '2',
                () => setModalState(() => formData['rating'] = '2'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                '3',
                '3',
                rating == '3',
                () => setModalState(() => formData['rating'] = '3'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttackForm(
    Map<String, dynamic> formData,
    StateSetter setModalState,
  ) {
    final result = formData['result'] as String? ?? 'in';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attack Result', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                'Kill',
                'kill',
                result == 'kill',
                () => setModalState(() => formData['result'] = 'kill'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'In',
                'in',
                result == 'in',
                () => setModalState(() => formData['result'] = 'in'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'Error',
                'error',
                result == 'error',
                () => setModalState(() => formData['result'] = 'error'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleButton(
    String label,
    String value,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.grey,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.1) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E5FF) : Colors.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _saveEditedEvent(
    BuildContext context,
    Event originalEvent,
    Player newPlayer,
    String newEventType,
    Map<String, dynamic> newMetadata,
  ) async {
    try {
      // Create updated event
      final updatedEvent = originalEvent.copyWith(
        player: newPlayer,
        type: EventType.values.firstWhere((e) => e.name == newEventType),
        metadata: newMetadata,
      );

      // Add to undo stack
      _addUndoAction(
        UndoAction(
          type: UndoActionType.update,
          originalEvent: originalEvent,
          updatedEvent: updatedEvent,
          description:
              'Update ${originalEvent.type.displayName} by ${originalEvent.player.fullName}',
        ),
      );

      // Update in database
      await _dbHelper.updateEvent(updatedEvent);

      // Update local state
      setState(() {
        // Update team events
        final teamIndex = _teamEvents.indexWhere(
          (e) => e.id == originalEvent.id,
        );
        if (teamIndex != -1) {
          _teamEvents[teamIndex] = updatedEvent;
        }

        // Update player events if player is selected
        if (_selectedPlayer != null) {
          final playerIndex = _playerEvents.indexWhere(
            (e) => e.id == originalEvent.id,
          );
          if (playerIndex != -1) {
            _playerEvents[playerIndex] = updatedEvent;
          }
        }

        // If the selected player changed, we need to reload player events
        if (originalEvent.player.id != newPlayer.id) {
          _loadPlayerEvents();
        }
      });

      Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event updated successfully'),
            backgroundColor: const Color(0xFF00FF88),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: _undoLastAction,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error updating event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating event: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    }
  }

  void _addUndoAction(UndoAction action) {
    _undoStack.add(action);
    // Clear redo stack when new action is performed
    _redoStack.clear();
    // Limit undo stack size
    if (_undoStack.length > maxUndoActions) {
      _undoStack.removeAt(0);
    }
  }

  bool _canRedo() {
    return _redoStack.isNotEmpty;
  }

  Future<void> _undoLastAction() async {
    if (_undoStack.isEmpty) return;

    final action = _undoStack.removeLast();
    // Add to redo stack for potential redo
    _redoStack.add(action);

    try {
      switch (action.type) {
        case UndoActionType.create:
          // Undo creation by deleting the event
          if (action.originalEvent != null) {
            await _dbHelper.deleteEvent(action.originalEvent!.id!);
            setState(() {
              _teamEvents.removeWhere((e) => e.id == action.originalEvent!.id);
              if (_selectedPlayer != null) {
                _playerEvents.removeWhere(
                  (e) => e.id == action.originalEvent!.id,
                );
              }
            });
          }
          break;

        case UndoActionType.delete:
          // Undo deletion by recreating the event
          if (action.originalEvent != null) {
            await _dbHelper.insertEvent(action.originalEvent!);
            setState(() {
              _teamEvents.add(action.originalEvent!);
              if (_selectedPlayer != null &&
                  action.originalEvent!.player.id == _selectedPlayer!.id) {
                _playerEvents.add(action.originalEvent!);
              }
            });
          }
          break;

        case UndoActionType.update:
          // Undo update by reverting to original event
          if (action.originalEvent != null) {
            await _dbHelper.updateEvent(action.originalEvent!);
            setState(() {
              final teamIndex = _teamEvents.indexWhere(
                (e) => e.id == action.originalEvent!.id,
              );
              if (teamIndex != -1) {
                _teamEvents[teamIndex] = action.originalEvent!;
              }
              if (_selectedPlayer != null) {
                final playerIndex = _playerEvents.indexWhere(
                  (e) => e.id == action.originalEvent!.id,
                );
                if (playerIndex != -1) {
                  _playerEvents[playerIndex] = action.originalEvent!;
                }
              }
            });
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undone: ${action.description}'),
            backgroundColor: const Color(0xFF00E5FF),
            action: SnackBarAction(
              label: 'Redo',
              textColor: Colors.white,
              onPressed: _redoLastAction,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error undoing action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error undoing action: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    }
  }

  Future<void> _redoLastAction() async {
    if (_redoStack.isEmpty) return;

    final action = _redoStack.removeLast();
    // Add back to undo stack
    _undoStack.add(action);

    try {
      switch (action.type) {
        case UndoActionType.create:
          // Redo creation by recreating the event
          if (action.originalEvent != null) {
            await _dbHelper.insertEvent(action.originalEvent!);
            setState(() {
              _teamEvents.add(action.originalEvent!);
              if (_selectedPlayer != null &&
                  action.originalEvent!.player.id == _selectedPlayer!.id) {
                _playerEvents.add(action.originalEvent!);
              }
            });
          }
          break;

        case UndoActionType.delete:
          // Redo deletion by deleting the event
          if (action.originalEvent != null) {
            await _dbHelper.deleteEvent(action.originalEvent!.id!);
            setState(() {
              _teamEvents.removeWhere((e) => e.id == action.originalEvent!.id);
              if (_selectedPlayer != null) {
                _playerEvents.removeWhere(
                  (e) => e.id == action.originalEvent!.id,
                );
              }
            });
          }
          break;

        case UndoActionType.update:
          // Redo update by applying the updated event
          if (action.updatedEvent != null) {
            await _dbHelper.updateEvent(action.updatedEvent!);
            setState(() {
              final teamIndex = _teamEvents.indexWhere(
                (e) => e.id == action.updatedEvent!.id,
              );
              if (teamIndex != -1) {
                _teamEvents[teamIndex] = action.updatedEvent!;
              }
              if (_selectedPlayer != null) {
                final playerIndex = _playerEvents.indexWhere(
                  (e) => e.id == action.updatedEvent!.id,
                );
                if (playerIndex != -1) {
                  _playerEvents[playerIndex] = action.updatedEvent!;
                }
              }
            });
          }
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redone: ${action.description}'),
            backgroundColor: const Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      print('Error redoing action: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error redoing action: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent(Event event) async {
    try {
      await _dbHelper.deleteEvent(event.id!);

      // Add to undo stack
      _addUndoAction(
        UndoAction(
          type: UndoActionType.delete,
          originalEvent: event,
          description:
              'Delete ${event.type.displayName} by ${event.player.fullName}',
        ),
      );

      // Remove from local lists
      setState(() {
        _teamEvents.removeWhere((e) => e.id == event.id);
        if (_selectedPlayer != null) {
          _playerEvents.removeWhere((e) => e.id == event.id);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event deleted successfully'),
            backgroundColor: const Color(0xFF00FF88),
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: _undoLastAction,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error deleting event: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    }
  }

  Widget _buildServingStats() {
    final servingStats = _getServingStats();
    final totalServes =
        servingStats['float']! +
        servingStats['hybrid']! +
        servingStats['spin']!;
    final subtitle =
        '$totalServes serves | Float:${servingStats['float']} | In:${servingStats['in']} | Error:${servingStats['error']}';

    return StatsSection(
      title: 'Serving',
      subtitle: subtitle,
      isLoading: _isLoadingPlayerStats,
      children: [
        // Serve Type Toggle
        ServeToggleRow(
          selectedValue: _selectedServeType,
          onChanged: (value) => setState(() => _selectedServeType = value),
          isDisabled: _selectedPlayer == null,
        ),
        const SizedBox(height: 8),
        // Serve Results
        StatButtonRow(
          buttons: [
            StatButtonData(
              label: 'Ace',
              color: const Color(0xFF00FF88),
              onPressed: () => _recordServeResult('ace'),
              isDisabled: _selectedPlayer == null,
            ),
            StatButtonData(
              label: 'In',
              color: const Color(0xFF00E5FF),
              onPressed: () => _recordServeResult('in'),
              isDisabled: _selectedPlayer == null,
            ),
            StatButtonData(
              label: 'Error',
              color: const Color(0xFFFF4444),
              onPressed: () => _recordServeResult('error'),
              isDisabled: _selectedPlayer == null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPassingStats() {
    final passingStats = _getPassingStats();
    final passingAverage = _getPassingAverage();
    final totalPasses = passingStats.values.reduce((a, b) => a + b);
    final subtitle =
        '$totalPasses attempts | ${passingAverage.toStringAsFixed(2)} average | Ace:${passingStats['ace']} | 1:${passingStats['1']} | 2:${passingStats['2']} | 3:${passingStats['3']} | 0:${passingStats['0']}';

    return StatsSection(
      title: 'Passing',
      subtitle: subtitle,
      isLoading: _isLoadingPlayerStats,
      children: [
        StatButtonRow(
          buttons: [
            StatButtonData(
              label: 'Ace',
              color: const Color(0xFF00FF88),
              onPressed: () => _recordPassRating('ace'),
              isDisabled: _selectedPlayer == null,
            ),
            StatButtonData(
              label: '0',
              color: const Color(0xFFFF4444),
              onPressed: () => _recordPassRating('0'),
              isDisabled: _selectedPlayer == null,
            ),
            StatButtonData(
              label: '1',
              color: const Color(0xFFFF8800),
              onPressed: () => _recordPassRating('1'),
              isDisabled: _selectedPlayer == null,
            ),
            StatButtonData(
              label: '2',
              color: const Color(0xFF00E5FF),
              onPressed: () => _recordPassRating('2'),
              isDisabled: _selectedPlayer == null,
            ),
            StatButtonData(
              label: '3',
              color: const Color(0xFF00FF88),
              onPressed: () => _recordPassRating('3'),
              isDisabled: _selectedPlayer == null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAttackingStats() {
    final attackingStats = _getAttackingStats();
    final totalAttacks = attackingStats.values.reduce((a, b) => a + b);
    final hitPercentage = totalAttacks > 0
        ? (attackingStats['kill']! - attackingStats['error']!) / totalAttacks
        : 0.0;
    final subtitle =
        '$totalAttacks attacks | .${(hitPercentage * 1000).round().toString().padLeft(3, '0')} hit | Kill:${attackingStats['kill']} | In:${attackingStats['in']} | Error:${attackingStats['error']}';

    return StatsSection(
      title: 'Attacking',
      subtitle: subtitle,
      isLoading: _isLoadingPlayerStats,
      children: [
        StatButtonRow(
          buttons: [
            StatButtonData(
              label: 'Kill',
              color: const Color(0xFF00FF88),
              onPressed: () => _recordAttackResult('kill'),
              isDisabled: _selectedPlayer == null,
            ),
            StatButtonData(
              label: 'In',
              color: const Color(0xFF00E5FF),
              onPressed: () => _recordAttackResult('in'),
              isDisabled: _selectedPlayer == null,
            ),
            StatButtonData(
              label: 'Error',
              color: const Color(0xFFFF4444),
              onPressed: () => _recordAttackResult('error'),
              isDisabled: _selectedPlayer == null,
            ),
          ],
        ),
      ],
    );
  }

  void _recordServeResult(String result) async {
    if (_selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a player first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedServeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a serve type first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final event = Event(
        practice: widget.practice,
        player: _selectedPlayer!,
        team: widget.practice.team,
        type: EventType.serve,
        metadata: {'result': result, 'serveType': _selectedServeType!},
        timestamp: DateTime.now(),
      );

      await _dbHelper.insertEvent(event);

      // Add to undo stack
      _addUndoAction(
        UndoAction(
          type: UndoActionType.create,
          originalEvent: event,
          description:
              'Create ${event.type.displayName} by ${event.player.fullName}',
        ),
      );

      // Update cache for the selected player
      if (_selectedPlayer?.id != null) {
        await _updatePlayerCache(_selectedPlayer!.id!);
        _playerEvents = _playerEventsCache[_selectedPlayer!.id!]!;
      }
      await _loadTeamEvents();

      final serveType = _selectedServeType!;

      // Clear the selected serve type after recording
      setState(() {
        _selectedServeType = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded $serveType serve: $result for ${_selectedPlayer!.fullName}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: _undoLastAction,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording serve: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _recordPassRating(String rating) async {
    if (_selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a player first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final event = Event(
        practice: widget.practice,
        player: _selectedPlayer!,
        team: widget.practice.team,
        type: EventType.pass,
        metadata: {'rating': rating},
        timestamp: DateTime.now(),
      );

      await _dbHelper.insertEvent(event);

      // Add to undo stack
      _addUndoAction(
        UndoAction(
          type: UndoActionType.create,
          originalEvent: event,
          description:
              'Create ${event.type.displayName} by ${event.player.fullName}',
        ),
      );

      // Update cache for the selected player
      if (_selectedPlayer?.id != null) {
        await _updatePlayerCache(_selectedPlayer!.id!);
        _playerEvents = _playerEventsCache[_selectedPlayer!.id!]!;
      }
      await _loadTeamEvents();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded pass rating: $rating for ${_selectedPlayer!.fullName}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: _undoLastAction,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording pass: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _recordAttackResult(String result) async {
    if (_selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a player first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final event = Event(
        practice: widget.practice,
        player: _selectedPlayer!,
        team: widget.practice.team,
        type: EventType.attack,
        metadata: {'result': result},
        timestamp: DateTime.now(),
      );

      await _dbHelper.insertEvent(event);

      // Add to undo stack
      _addUndoAction(
        UndoAction(
          type: UndoActionType.create,
          originalEvent: event,
          description:
              'Create ${event.type.displayName} by ${event.player.fullName}',
        ),
      );

      // Update cache for the selected player
      if (_selectedPlayer?.id != null) {
        await _updatePlayerCache(_selectedPlayer!.id!);
        _playerEvents = _playerEventsCache[_selectedPlayer!.id!]!;
      }
      await _loadTeamEvents();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded attack: $result for ${_selectedPlayer!.fullName}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: _undoLastAction,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording attack: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Aggregate stats calculation methods
  Map<String, int> _getServingStats() {
    final eventsToUse = (_selectedPlayer != null && !_isLoadingPlayerStats)
        ? _playerEvents
        : _teamEvents;
    final serveEvents = eventsToUse
        .where((e) => e.type == EventType.serve)
        .toList();
    final stats = <String, int>{
      'float': 0,
      'hybrid': 0,
      'spin': 0,
      'ace': 0,
      'in': 0,
      'error': 0,
    };

    for (final event in serveEvents) {
      final result = event.metadata['result'] as String?;
      final serveType = event.metadata['serveType'] as String?;

      if (serveType != null) {
        stats[serveType] = (stats[serveType] ?? 0) + 1;
      }
      if (result != null) {
        stats[result] = (stats[result] ?? 0) + 1;
      }
    }

    return stats;
  }

  Map<String, int> _getPassingStats() {
    final eventsToUse = (_selectedPlayer != null && !_isLoadingPlayerStats)
        ? _playerEvents
        : _teamEvents;
    final passEvents = eventsToUse
        .where((e) => e.type == EventType.pass)
        .toList();
    final stats = <String, int>{'ace': 0, '0': 0, '1': 0, '2': 0, '3': 0};

    for (final event in passEvents) {
      final rating = event.metadata['rating'] as String?;
      if (rating != null) {
        stats[rating] = (stats[rating] ?? 0) + 1;
      }
    }

    return stats;
  }

  Map<String, int> _getAttackingStats() {
    final eventsToUse = (_selectedPlayer != null && !_isLoadingPlayerStats)
        ? _playerEvents
        : _teamEvents;
    final attackEvents = eventsToUse
        .where((e) => e.type == EventType.attack)
        .toList();
    final stats = <String, int>{'kill': 0, 'in': 0, 'error': 0};

    for (final event in attackEvents) {
      final result = event.metadata['result'] as String?;
      if (result != null) {
        stats[result] = (stats[result] ?? 0) + 1;
      }
    }

    return stats;
  }

  double _getPassingAverage() {
    final eventsToUse = (_selectedPlayer != null && !_isLoadingPlayerStats)
        ? _playerEvents
        : _teamEvents;
    final passEvents = eventsToUse
        .where((e) => e.type == EventType.pass)
        .toList();
    if (passEvents.isEmpty) return 0.0;

    int totalPoints = 0;
    for (final event in passEvents) {
      final rating = event.metadata['rating'] as String?;
      if (rating != null) {
        switch (rating) {
          case 'ace':
            totalPoints += 0; // ACE is worth 0 points
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
    }

    return totalPoints / passEvents.length;
  }

  // Stats calculation methods (copied from team stats page)
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

  Widget _buildTeamStatsTable() {
    if (_teamPlayers.isEmpty) {
      return const Center(
        child: Text(
          'No players added yet.\nAdd players to see team statistics.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final columnWidths = TeamStatsTable.calculateColumnWidths(
      _teamPlayers,
      _teamEvents,
      _getPlayerServingStats,
      _getPlayerPassingStats,
      _getPlayerAttackingStats,
    );

    return TeamStatsTable.buildPlayerStatsTable(
      context,
      columnWidths,
      _teamPlayers,
      _teamEvents,
      _getPlayerServingStats,
      _getPlayerPassingStats,
      _getPlayerAttackingStats,
    );
  }
}
