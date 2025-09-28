import 'package:flutter/material.dart';
import '../models/practice.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../models/team.dart';
import '../database_helper.dart';
import '../services/player_service.dart';
import '../services/event_service.dart';
import '../services/team_service.dart';
import 'practice_analysis_page.dart';
import '../viz/player_stats_table.dart';
import '../widgets/volleyball_court.dart';
import '../utils/date_utils.dart';

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

class PracticeCollectionPage extends StatefulWidget {
  final Practice practice;

  const PracticeCollectionPage({super.key, required this.practice});

  @override
  State<PracticeCollectionPage> createState() => _PracticeCollectionPageState();
}

class _PracticeCollectionPageState extends State<PracticeCollectionPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final PlayerService _playerService = PlayerService();
  final EventService _eventService = EventService();
  final TeamService _teamService = TeamService();
  List<Player> _teamPlayers = [];
  List<Player> _allPlayers = [];
  Player? _selectedPlayer;
  bool _isLoading = true;
  List<Event> _playerEvents = [];

  // Court coordinate tracking
  bool _isRecordingCoordinates = false;
  String? _recordingAction;
  double? _startX;
  double? _startY;
  double? _endX;
  double? _endY;
  bool _hasStartPoint = false;

  // Display coordinates (original, not normalized)
  double? _displayStartX;
  double? _displayStartY;
  double? _displayEndX;
  double? _displayEndY;

  // Action selection for iterative stats
  String? _selectedActionType; // 'serve', 'pass', 'attack'
  String? _selectedServeResult; // 'ace', 'in', 'error'
  String? _selectedPassRating; // 'ace', '3', '2', '1', '0'
  String? _selectedAttackResult; // 'kill', 'in', 'error'
  List<Event> _teamEvents = [];
  String? _selectedServeType;
  bool _isLoadingPlayerStats = false;

  // Attack metadata selection (multiple selection)
  Set<String> _selectedAttackMetadata = {};

  // Pass type selection (single selection)
  String? _selectedPassType;

  // Freeball action selection
  String? _selectedFreeballAction; // 'sent' or 'received'
  String? _selectedFreeballResult; // 'good' or 'bad' (for received only)

  // Caching system
  Map<int, List<Event>> _playerEventsCache = {};

  // Court coordinate methods

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
      final practicePlayers = await _playerService.getPracticePlayers(
        widget.practice.id!,
      );
      final allPlayers = await _playerService.getAllPlayers();
      final teamEvents = await _eventService.getEventsForPractice(
        widget.practice.id!,
      );

      print(
        'Practice ${widget.practice.id} has ${practicePlayers.length} players',
      );
      for (final player in practicePlayers) {
        print('  - ${player.fullName} (ID: ${player.id})');
      }

      setState(() {
        _teamPlayers = _sortPlayers(practicePlayers);
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
        title: Text(
          '${widget.practice.team.teamName} Practice - ${DateFormatter.formatDate(widget.practice.date)}',
        ),
        actions: [
          if (_undoStack.isNotEmpty)
            IconButton(
              onPressed: _undoLastAction,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo ${_undoStack.last.description}',
            ),
          IconButton(
            onPressed: () => _navigateToStatsDashboard(context),
            icon: const Icon(Icons.analytics),
            tooltip: 'View Team Stats',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : SafeArea(
              child: Row(
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
                          // Add Player and Team Buttons
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _addPlayerToPractice,
                                    icon: const Icon(
                                      Icons.person_add,
                                      size: 16,
                                    ),
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
                                : ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: _teamPlayers.length,
                                    itemBuilder: (context, index) {
                                      final player = _teamPlayers[index];
                                      final isSelected =
                                          _selectedPlayer?.id == player.id;
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(
                                                  0xFF00E5FF,
                                                ).withOpacity(0.1)
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            height:
                                                36, // Fixed height for short tiles
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                // Jersey number (if available)
                                                if (player.jerseyNumber !=
                                                    null) ...[
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF00E5FF,
                                                            )
                                                          : Colors.grey[600],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '${player.jerseyNumber}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                // Player name
                                                Expanded(
                                                  child: Text(
                                                    player.fullName,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF00E5FF,
                                                            )
                                                          : null,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
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
                      child: SingleChildScrollView(
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
            ),
    );
  }

  void _navigateToStatsDashboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PracticeAnalysisPage(practice: widget.practice),
      ),
    );
  }

  // Sort players by jersey number, then first name, then last name
  List<Player> _sortPlayers(List<Player> players) {
    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) {
      // First sort by jersey number (nulls last)
      final aJersey = a.jerseyNumber;
      final bJersey = b.jerseyNumber;

      if (aJersey == null && bJersey == null) {
        // Both null, sort by first name
      } else if (aJersey == null) {
        return 1; // a comes after b
      } else if (bJersey == null) {
        return -1; // a comes before b
      } else {
        final jerseyCompare = aJersey.compareTo(bJersey);
        if (jerseyCompare != 0) return jerseyCompare;
      }

      // Then sort by first name
      final aFirstName = a.firstName ?? '';
      final bFirstName = b.firstName ?? '';
      final firstNameCompare = aFirstName.compareTo(bFirstName);
      if (firstNameCompare != 0) return firstNameCompare;

      // Finally sort by last name
      final aLastName = a.lastName ?? '';
      final bLastName = b.lastName ?? '';
      return aLastName.compareTo(bLastName);
    });

    return sortedPlayers;
  }

  Future<void> _initializePlayerCache() async {
    if (_cacheInitialized) return;

    try {
      // Pre-load events for all team players
      for (final player in _teamPlayers) {
        if (player.id != null) {
          final events = await _eventService.getEventsForPlayer(player.id!);
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
        _selectedActionType = null; // Clear action type selection
        _selectedServeResult = null; // Clear serve result selection
        _selectedPassRating = null; // Clear pass rating selection
        _selectedPassType = null; // Clear pass type selection
        _selectedAttackResult = null; // Clear attack result selection
        _selectedAttackMetadata.clear(); // Clear attack metadata
        _selectedFreeballAction = null; // Clear freeball action selection
        _selectedFreeballResult = null; // Clear freeball result selection
        // Keep coordinates when unselecting player
        _isLoadingPlayerStats = false;
      });
    } else {
      // Select the new player
      setState(() {
        _selectedPlayer = player;
        _selectedServeType = null; // Clear serve type selection
        _selectedActionType = null; // Clear action type selection
        _selectedServeResult = null; // Clear serve result selection
        _selectedPassRating = null; // Clear pass rating selection
        _selectedPassType = null; // Clear pass type selection
        _selectedAttackResult = null; // Clear attack result selection
        _selectedAttackMetadata.clear(); // Clear attack metadata
        _selectedFreeballAction = null; // Clear freeball action selection
        _selectedFreeballResult = null; // Clear freeball result selection
        // Keep coordinates when selecting new player
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
      final events = await _eventService.getEventsForPlayer(
        _selectedPlayer!.id!,
      );
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
      final events = await _eventService.getEventsForPlayer(playerId);
      _playerEventsCache[playerId] = events;
    } catch (e) {
      print('Error updating player cache for player $playerId: $e');
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
                            await _playerService.addPlayerToPractice(
                              widget.practice.id!,
                              player.id!,
                            );

                            // Update local state
                            setState(() {
                              _teamPlayers.add(player);
                              _teamPlayers = _sortPlayers(_teamPlayers);
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
          future: _teamService.getAllTeams(),
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
                          final allPlayers = await _playerService
                              .getAllPlayers();
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
                            await _playerService.addPlayerToPractice(
                              widget.practice.id!,
                              player.id!,
                            );
                          }

                          // Update local state
                          setState(() {
                            _teamPlayers.addAll(newPlayers);
                            _teamPlayers = _sortPlayers(_teamPlayers);
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
      await _playerService.removePlayerFromPractice(
        widget.practice.id!,
        player.id!,
      );

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // All Actions Collection
        _buildAllActionsTile(),
        const SizedBox(height: 8),
        VolleyballCourt(
          onCourtTap: _onCourtTap,
          onClear: _clearCoordinates,
          startX: _displayStartX,
          startY: _displayStartY,
          endX: _displayEndX,
          endY: _displayEndY,
          hasStartPoint: _hasStartPoint,
          selectedAction: _recordingAction,
          isRecording: true, // Always allow coordinate recording
        ),
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
        onTap: () => _showEventOptionsModal(event),
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
          trailing: _buildMiniCourt(
            event.fromX,
            event.fromY,
            event.toX,
            event.toY,
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
            'Event Details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: SizedBox(
            width: 900,
            child: Row(
              children: [
                // Left column - Event details
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEventDetailRow('Player', event.player.fullName),
                        _buildEventDetailRow('Type', event.type.displayName),
                        _buildEventDetailRow(
                          'Time',
                          '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}',
                        ),
                        _buildEventDetailRow(
                          'Date',
                          '${event.timestamp.month}/${event.timestamp.day}/${event.timestamp.year}',
                        ),

                        // Metadata
                        if (event.metadata.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Details:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...event.metadata.entries.map(
                            (entry) => _buildEventDetailRow(
                              _formatMetadataKey(entry.key),
                              entry.value.toString(),
                            ),
                          ),
                        ],

                        // Coordinates
                        if (event.hasCoordinates) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Coordinates:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (event.hasFromCoordinates)
                            _buildEventDetailRow(
                              'Start',
                              '${event.fromX!.toStringAsFixed(1)}ft, ${event.fromY!.toStringAsFixed(1)}ft',
                            ),
                          if (event.hasToCoordinates)
                            _buildEventDetailRow(
                              'End',
                              '${event.toX!.toStringAsFixed(1)}ft, ${event.toY!.toStringAsFixed(1)}ft',
                            ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Right column - Court visualization
                if (event.hasCoordinates)
                  Column(
                    children: [
                      const Text(
                        'Court Position',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      VolleyballCourt(
                        startX: event.fromX,
                        startY: event.fromY,
                        endX: event.toX,
                        endY: event.toY,
                        hasStartPoint: event.hasFromCoordinates,
                        selectedAction: event.type.name,
                        isRecording: false,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
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

    // Initialize coordinate editing state
    double? editStartX = event.fromX;
    double? editStartY = event.fromY;
    double? editEndX = event.toX;
    double? editEndY = event.toY;
    bool editHasStartPoint = event.hasFromCoordinates;

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

                    const SizedBox(height: 16),

                    // Coordinate editing section
                    const Text(
                      'Coordinates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Clear coordinates button
                    if (editStartX != null || editEndX != null)
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            editStartX = null;
                            editStartY = null;
                            editEndX = null;
                            editEndY = null;
                            editHasStartPoint = false;
                          });
                        },
                        child: const Text('Clear Coordinates'),
                      ),

                    const SizedBox(height: 8),

                    // Volleyball Court
                    Center(
                      child: VolleyballCourt(
                        startX: editStartX,
                        startY: editStartY,
                        endX: editEndX,
                        endY: editEndY,
                        hasStartPoint: editHasStartPoint,
                        selectedAction: selectedEventType,
                        isRecording: true, // Always allow editing
                        onCourtTap: (x, y) {
                          setModalState(() {
                            // Check if tapping near existing start point (within 2 feet)
                            if (editStartX != null && editStartY != null) {
                              final distanceToStart =
                                  ((x - editStartX!) * (x - editStartX!) +
                                  (y - editStartY!) * (y - editStartY!));

                              if (distanceToStart < 4.0) {
                                // Within ~2 feet (4 square feet)
                                // Remove start point
                                editStartX = null;
                                editStartY = null;
                                editHasStartPoint = false;
                                return;
                              }
                            }

                            // Check if tapping near existing end point (within 2 feet)
                            if (editEndX != null && editEndY != null) {
                              final distanceToEnd =
                                  ((x - editEndX!) * (x - editEndX!) +
                                  (y - editEndY!) * (y - editEndY!));

                              if (distanceToEnd < 4.0) {
                                // Within ~2 feet (4 square feet)
                                // Remove end point
                                editEndX = null;
                                editEndY = null;
                                return;
                              }
                            }

                            // If not tapping on existing points, set new coordinates
                            if (!editHasStartPoint) {
                              editStartX = x;
                              editStartY = y;
                              editHasStartPoint = true;
                            } else {
                              editEndX = x;
                              editEndY = y;
                            }
                          });
                        },
                        onClear: () {
                          setModalState(() {
                            editStartX = null;
                            editStartY = null;
                            editEndX = null;
                            editEndY = null;
                            editHasStartPoint = false;
                          });
                        },
                      ),
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
                    editStartX,
                    editStartY,
                    editEndX,
                    editEndY,
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
    double? newFromX,
    double? newFromY,
    double? newToX,
    double? newToY,
  ) async {
    try {
      // Normalize coordinates so first point is always on left half
      final normalizedCoords = _normalizeCoordinates(
        newFromX,
        newFromY,
        newToX,
        newToY,
      );

      // Create updated event
      final updatedEvent = originalEvent.copyWith(
        player: newPlayer,
        type: EventType.values.firstWhere((e) => e.name == newEventType),
        metadata: newMetadata,
        fromX: normalizedCoords['fromX'],
        fromY: normalizedCoords['fromY'],
        toX: normalizedCoords['toX'],
        toY: normalizedCoords['toY'],
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
      await _eventService.updateEvent(updatedEvent);

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
            await _eventService.deleteEvent(action.originalEvent!.id!);
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
            await _eventService.insertEvent(action.originalEvent!);
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
            await _eventService.updateEvent(action.originalEvent!);
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
            await _eventService.insertEvent(action.originalEvent!);
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
            await _eventService.deleteEvent(action.originalEvent!.id!);
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
            await _eventService.updateEvent(action.updatedEvent!);
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
      await _eventService.deleteEvent(event.id!);

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

    // Calculate column widths (complete version matching PlayerStatsTable expectations)
    final columnWidths = <String, double>{
      'Player': 120.0,
      'Jersey': 60.0,
      'Serves': 60.0,
      'Aces': 50.0,
      'In': 40.0,
      'Errors': 60.0,
      'Float': 50.0,
      'Hybrid': 60.0,
      'Spin': 50.0,
      'Passes': 60.0,
      'Average': 70.0,
      'Ace': 30.0, // Note: 'Ace' for passing stats, not 'Aces'
      '0': 30.0,
      '1': 30.0,
      '2': 30.0,
      '3': 30.0,
      'Attacks': 70.0,
      'Kills': 50.0,
      'Hit %': 60.0,
    };

    return PlayerStatsTable(
      columnWidths: columnWidths,
      teamPlayers: _teamPlayers,
      teamEvents: _teamEvents,
      getPlayerServingStats: _getPlayerServingStats,
      getPlayerPassingStats: _getPlayerPassingStats,
      getPlayerAttackingStats: _getPlayerAttackingStats,
    );
  }

  Widget _buildAllActionsTile() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            Column(
              children: [
                // First Row: Serve and Pass
                IntrinsicHeight(
                  child: Row(
                    children: [
                      // Serve Column
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF00E5FF),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // Serve Title
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: const Text(
                                    'SERVE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Serve Types
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Float',
                                        const Color(0xFF00E5FF),
                                        () => _selectServeType('float'),
                                        _selectedServeType == 'float',
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Hybrid',
                                        const Color(0xFF00E5FF),
                                        () => _selectServeType('hybrid'),
                                        _selectedServeType == 'hybrid',
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Spin',
                                        const Color(0xFF00E5FF),
                                        () => _selectServeType('spin'),
                                        _selectedServeType == 'spin',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                // Serve Results
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Ace',
                                        const Color(0xFF00FF88),
                                        () => _selectServeResult('ace'),
                                        _selectedServeResult == 'ace',
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: _buildCompactButton(
                                        'In',
                                        const Color(0xFF00FF88),
                                        () => _selectServeResult('in'),
                                        _selectedServeResult == 'in',
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Error',
                                        const Color(0xFFFF4444),
                                        () => _selectServeResult('error'),
                                        _selectedServeResult == 'error',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 4),

                      // Pass Column
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF00FF88),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // Pass Title
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: const Text(
                                    'PASS',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF00FF88),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Pass Ratings
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Ace',
                                        const Color(0xFF00FF88),
                                        () => _selectPassRating('ace'),
                                        _selectedPassRating == 'ace',
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                    Expanded(
                                      child: _buildCompactButton(
                                        '3',
                                        const Color(0xFF00FF88),
                                        () => _selectPassRating('3'),
                                        _selectedPassRating == '3',
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                    Expanded(
                                      child: _buildCompactButton(
                                        '2',
                                        const Color(0xFF00E5FF),
                                        () => _selectPassRating('2'),
                                        _selectedPassRating == '2',
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                    Expanded(
                                      child: _buildCompactButton(
                                        '1',
                                        const Color(0xFFFF8800),
                                        () => _selectPassRating('1'),
                                        _selectedPassRating == '1',
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                    Expanded(
                                      child: _buildCompactButton(
                                        '0',
                                        const Color(0xFFFF4444),
                                        () => _selectPassRating('0'),
                                        _selectedPassRating == '0',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Pass Type
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildPassTypeButton(
                                      'Overhand',
                                      'overhand',
                                      const Color(0xFF00FF88),
                                    ),
                                    _buildPassTypeButton(
                                      'Platform',
                                      'platform',
                                      const Color(0xFF00FF88),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Second Row: Attack and Freeball
                IntrinsicHeight(
                  child: Row(
                    children: [
                      // Attack Column
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFFF8800),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // Attack Title
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: const Text(
                                    'ATTACK',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFFF8800),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Attack Results
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Kill',
                                        const Color(0xFF00FF88),
                                        () => _selectAttackResult('kill'),
                                        _selectedAttackResult == 'kill',
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: _buildCompactButton(
                                        'In',
                                        const Color(0xFF00E5FF),
                                        () => _selectAttackResult('in'),
                                        _selectedAttackResult == 'in',
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Error',
                                        const Color(0xFFFF4444),
                                        () => _selectAttackResult('error'),
                                        _selectedAttackResult == 'error',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Attack Metadata
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildMetadataButton(
                                          'Tip',
                                          'tip',
                                          const Color(0xFF9C27B0),
                                        ),
                                        _buildMetadataButton(
                                          'Shot',
                                          'shot',
                                          const Color(0xFF2196F3),
                                        ),
                                        _buildMetadataButton(
                                          'Blocked',
                                          'blocked',
                                          const Color(0xFFFF9800),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildMetadataButton(
                                          'Recycle',
                                          'recycle',
                                          const Color(0xFF4CAF50),
                                        ),
                                        _buildMetadataButton(
                                          'Tool',
                                          'tool',
                                          const Color(0xFF607D8B),
                                        ),
                                        _buildMetadataButton(
                                          'Deflected',
                                          'deflected',
                                          const Color(0xFFE91E63),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 4),

                      // Freeball Column
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFF9C27B0),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              children: [
                                // Freeball Title
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: const Text(
                                    'FREEBALL',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF9C27B0),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Freeball Actions
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Sent',
                                        const Color(0xFF9C27B0),
                                        () => _selectFreeballAction('sent'),
                                        _selectedFreeballAction == 'sent',
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: _buildCompactButton(
                                        'Received',
                                        const Color(0xFF9C27B0),
                                        () => _selectFreeballAction('received'),
                                        _selectedFreeballAction == 'received',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Freeball Result (only for received)
                                if (_selectedFreeballAction == 'received')
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildFreeballResultButton(
                                        'Good',
                                        'good',
                                        const Color(0xFF00FF88),
                                      ),
                                      _buildFreeballResultButton(
                                        'Bad',
                                        'bad',
                                        const Color(0xFFFF4444),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Single Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canSaveAction() ? _saveCurrentAction : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getSaveButtonColor(),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  _getSaveButtonText(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton(
    String label,
    Color color,
    VoidCallback onPressed,
    bool isSelected,
  ) {
    final bool isDisabled = _selectedPlayer == null;

    // Check if this is a serve type button
    final bool isServeType = ['Float', 'Hybrid', 'Spin'].contains(label);
    final Color buttonColor = isServeType ? Colors.orange : Colors.blue;

    return OutlinedButton(
      onPressed: isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDisabled ? Colors.grey : buttonColor,
        backgroundColor: isSelected
            ? buttonColor.withOpacity(0.2)
            : Colors.transparent,
        side: BorderSide(
          color: isDisabled
              ? Colors.grey
              : (isSelected ? buttonColor : buttonColor),
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: isDisabled ? Colors.grey : buttonColor,
        ),
      ),
    );
  }

  Widget _buildMetadataButton(String label, String value, Color color) {
    final bool isDisabled = _selectedPlayer == null;
    final bool isSelected = _selectedAttackMetadata.contains(value);
    final Color buttonColor = isDisabled ? Colors.grey : color;

    return OutlinedButton(
      onPressed: isDisabled ? null : () => _toggleAttackMetadata(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDisabled ? Colors.grey : buttonColor,
        backgroundColor: isSelected
            ? buttonColor.withOpacity(0.3)
            : Colors.transparent,
        side: BorderSide(
          color: isDisabled
              ? Colors.grey
              : (isSelected ? buttonColor : buttonColor.withOpacity(0.5)),
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: isDisabled ? Colors.grey : buttonColor,
        ),
      ),
    );
  }

  Widget _buildPassTypeButton(String label, String value, Color color) {
    final bool isDisabled = _selectedPlayer == null;
    final bool isSelected = _selectedPassType == value;
    final Color buttonColor = isDisabled ? Colors.grey : color;

    return OutlinedButton(
      onPressed: isDisabled ? null : () => _selectPassType(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDisabled ? Colors.grey : buttonColor,
        backgroundColor: isSelected
            ? buttonColor.withOpacity(0.3)
            : Colors.transparent,
        side: BorderSide(
          color: isDisabled
              ? Colors.grey
              : (isSelected ? buttonColor : buttonColor.withOpacity(0.5)),
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: isDisabled ? Colors.grey : buttonColor,
        ),
      ),
    );
  }

  Widget _buildFreeballResultButton(String label, String value, Color color) {
    final bool isDisabled = _selectedPlayer == null;
    final bool isSelected = _selectedFreeballResult == value;
    final Color buttonColor = isDisabled ? Colors.grey : color;

    return OutlinedButton(
      onPressed: isDisabled ? null : () => _selectFreeballResult(value),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDisabled ? Colors.grey : buttonColor,
        backgroundColor: isSelected
            ? buttonColor.withOpacity(0.3)
            : Colors.transparent,
        side: BorderSide(
          color: isDisabled
              ? Colors.grey
              : (isSelected ? buttonColor : buttonColor.withOpacity(0.5)),
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: isDisabled ? Colors.grey : buttonColor,
        ),
      ),
    );
  }

  Widget _buildMiniCourt(
    double? fromX,
    double? fromY,
    double? toX,
    double? toY,
  ) {
    // If no coordinates, show a simple placeholder
    if (fromX == null && fromY == null && toX == null && toY == null) {
      return SizedBox(
        width: 60,
        height: 40,
        child: Container(
          child: const Center(
            child: Icon(Icons.location_off, size: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      width: 60,
      height: 40,
      child: CustomPaint(
        painter: _MiniCourtPainter(
          fromX: fromX,
          fromY: fromY,
          toX: toX,
          toY: toY,
        ),
      ),
    );
  }

  bool _canSaveAction() {
    if (_selectedPlayer == null) {
      return false;
    }

    // Check if any action type is selected (metadata is optional)
    if (_selectedServeType != null || _selectedServeResult != null) {
      return true;
    }
    if (_selectedPassRating != null) {
      return true;
    }
    if (_selectedAttackResult != null) {
      return true;
    }
    if (_selectedFreeballAction != null) {
      return true;
    }

    return false;
  }

  Color _getSaveButtonColor() {
    if (_selectedServeType != null || _selectedServeResult != null) {
      return const Color(0xFF00E5FF); // Blue for serve
    }
    if (_selectedPassRating != null) {
      return const Color(0xFF00FF88); // Green for pass
    }
    if (_selectedAttackResult != null) {
      return const Color(0xFFFF8800); // Orange for attack
    }
    if (_selectedFreeballAction != null) {
      return const Color(0xFF9C27B0); // Purple for freeball
    }
    return Colors.grey;
  }

  String _getSaveButtonText() {
    if (_selectedServeType != null || _selectedServeResult != null) {
      return 'Save Serve';
    }
    if (_selectedPassRating != null) {
      return 'Save Pass';
    }
    if (_selectedAttackResult != null) {
      return 'Save Attack';
    }
    if (_selectedFreeballAction != null) {
      return 'Save Freeball';
    }
    return 'Select Action';
  }

  void _saveCurrentAction() {
    if (_selectedServeType != null || _selectedServeResult != null) {
      _saveServeAction();
    } else if (_selectedPassRating != null) {
      _savePassAction();
    } else if (_selectedAttackResult != null) {
      _saveAttackAction();
    } else if (_selectedFreeballAction != null) {
      _saveFreeballAction();
    }
  }

  void _selectServeType(String type) {
    setState(() {
      // Clear other action selections
      _selectedPassRating = null;
      _selectedPassType = null;
      _selectedAttackResult = null;
      _selectedAttackMetadata.clear();
      _selectedFreeballAction = null;
      _selectedFreeballResult = null;
      _selectedAttackMetadata.clear();
      _selectedServeResult = null;

      // Set serve type
      _selectedServeType = type;
      // Don't clear coordinates when changing action
    });
  }

  void _saveServeAction() async {
    if (_selectedPlayer == null) {
      return;
    }

    // Get the team from the practice
    final team = widget.practice.team;

    // Normalize coordinates so first point is always on left half
    // Apply coordinate normalization only when saving
    final normalizedCoords = _normalizeCoordinates(
      _startX,
      _startY,
      _endX,
      _endY,
    );

    // Create a temporary event to store the serve type
    final tempEvent = Event(
      id: DateTime.now().millisecondsSinceEpoch,
      practice: widget.practice,
      match: null,
      player: _selectedPlayer!,
      team: team,
      type: EventType.serve,
      metadata: {
        'serveType': _selectedServeType ?? 'unknown',
        'result': _selectedServeResult ?? 'unknown',
      },
      timestamp: DateTime.now(),
      fromX: normalizedCoords['fromX'],
      fromY: normalizedCoords['fromY'],
      toX: normalizedCoords['toX'],
      toY: normalizedCoords['toY'],
    );

    try {
      await _eventService.insertEvent(tempEvent);

      // Reset the serve selections and coordinates
      setState(() {
        _selectedPlayer = null;
        _selectedActionType = null;
        _selectedServeType = null;
        _selectedServeResult = null;
        _isRecordingCoordinates = false;
        _recordingAction = null;
        _hasStartPoint = false;
        _startX = null;
        _startY = null;
        _endX = null;
        _endY = null;
        _displayStartX = null;
        _displayStartY = null;
        _displayEndX = null;
        _displayEndY = null;
      });

      // Refresh team players to update stats
      await _loadTeamPlayers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Serve saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving serve action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectServeResult(String result) {
    setState(() {
      // Clear other action selections
      _selectedPassRating = null;
      _selectedPassType = null;
      _selectedAttackResult = null;
      _selectedAttackMetadata.clear();
      _selectedFreeballAction = null;
      _selectedFreeballResult = null;

      // Set serve result (but keep serve type if already selected)
      _selectedServeResult = result;
      // Don't clear coordinates when changing action
    });
  }

  void _selectPassRating(String rating) {
    setState(() {
      // Clear other action selections
      _selectedServeType = null;
      _selectedServeResult = null;
      _selectedAttackResult = null;

      // Set pass rating
      _selectedPassRating = rating;
      // Don't clear coordinates when changing action
    });
  }

  void _selectAttackResult(String result) {
    setState(() {
      // Clear other action selections
      _selectedServeType = null;
      _selectedServeResult = null;
      _selectedPassRating = null;

      // Set attack result
      _selectedAttackResult = result;
      // Don't clear coordinates when changing action
      // Keep attack metadata when switching results
    });
  }

  void _toggleAttackMetadata(String metadata) {
    setState(() {
      if (_selectedAttackMetadata.contains(metadata)) {
        _selectedAttackMetadata.remove(metadata);
      } else {
        _selectedAttackMetadata.add(metadata);
      }
    });
  }

  void _selectPassType(String passType) {
    setState(() {
      if (_selectedPassType == passType) {
        // If the same type is selected, deselect it
        _selectedPassType = null;
      } else {
        // Select the new type
        _selectedPassType = passType;
      }
    });
  }

  void _selectFreeballAction(String action) {
    setState(() {
      // Clear other action selections
      _selectedServeType = null;
      _selectedServeResult = null;
      _selectedPassRating = null;
      _selectedPassType = null;
      _selectedAttackResult = null;
      _selectedAttackMetadata.clear();

      // Set freeball action
      _selectedFreeballAction = action;
      // Clear result when switching actions
      _selectedFreeballResult = null;
    });
  }

  void _selectFreeballResult(String result) {
    setState(() {
      if (_selectedFreeballResult == result) {
        // If the same result is selected, deselect it
        _selectedFreeballResult = null;
      } else {
        // Select the new result
        _selectedFreeballResult = result;
      }
    });
  }

  Widget _buildEventDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _formatMetadataKey(String key) {
    // Convert snake_case to Title Case
    return key
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1)
              : word,
        )
        .join(' ');
  }

  void _startCoordinateRecording(String action) {
    setState(() {
      _isRecordingCoordinates = true;
      _recordingAction = action;
      // Don't clear existing coordinates - allow recording over them
    });
  }

  void _onCourtTap(double x, double y) {
    // Allow coordinate recording anytime, regardless of player/action selection

    setState(() {
      if (!_hasStartPoint) {
        // First tap - set start point
        _displayStartX = x;
        _displayStartY = y;
        _hasStartPoint = true;
      } else {
        // Second tap - set end point
        _displayEndX = x;
        _displayEndY = y;
        // Keep recording state true so points remain visible
      }

      // Store display coordinates directly (no flipping for display)
      _startX = _displayStartX;
      _startY = _displayStartY;
      _endX = _displayEndX;
      _endY = _displayEndY;
    });
  }

  void _clearCoordinates() {
    setState(() {
      _hasStartPoint = false;
      _startX = null;
      _startY = null;
      _endX = null;
      _endY = null;
      _displayStartX = null;
      _displayStartY = null;
      _displayEndX = null;
      _displayEndY = null;
    });
  }

  // Normalize coordinates so the first point is always on the left half
  Map<String, double?> _normalizeCoordinates(
    double? startX,
    double? startY,
    double? endX,
    double? endY,
  ) {
    if (startX == null || startY == null || endX == null || endY == null) {
      return {'fromX': startX, 'fromY': startY, 'toX': endX, 'toY': endY};
    }

    // If the first point is on the right side (X > 0.5), flip both coordinates
    if (startX > 0.5) {
      return {
        'fromX': 1.0 - startX, // Flip START point's X
        'fromY': 1.0 - startY, // Flip START point's Y
        'toX': 1.0 - endX, // Flip END point's X
        'toY': 1.0 - endY, // Flip END point's Y
      };
    } else {
      // First point is already on the left, keep as is
      return {'fromX': startX, 'fromY': startY, 'toX': endX, 'toY': endY};
    }
  }

  void _savePassAction() async {
    if (_selectedPlayer == null) {
      return;
    }

    final team = widget.practice.team;

    // Normalize coordinates so first point is always on left half
    final normalizedCoords = _normalizeCoordinates(
      _startX,
      _startY,
      _endX,
      _endY,
    );

    // Create metadata map with rating and pass type
    final metadata = <String, dynamic>{
      'rating': _selectedPassRating ?? 'unknown',
    };

    // Add pass type if selected
    if (_selectedPassType != null) {
      metadata['pass_type'] = _selectedPassType;
    }

    final tempEvent = Event(
      id: DateTime.now().millisecondsSinceEpoch,
      practice: widget.practice,
      match: null,
      player: _selectedPlayer!,
      team: team,
      type: EventType.pass,
      metadata: metadata,
      timestamp: DateTime.now(),
      fromX: normalizedCoords['fromX'],
      fromY: normalizedCoords['fromY'],
      toX: normalizedCoords['toX'],
      toY: normalizedCoords['toY'],
    );

    try {
      await _eventService.insertEvent(tempEvent);

      setState(() {
        _selectedPlayer = null;
        _selectedActionType = null;
        _selectedPassRating = null;
        _selectedPassType = null;
        _isRecordingCoordinates = false;
        _recordingAction = null;
        _hasStartPoint = false;
        _startX = null;
        _startY = null;
        _endX = null;
        _endY = null;
        _displayStartX = null;
        _displayStartY = null;
        _displayEndX = null;
        _displayEndY = null;
      });

      await _loadTeamPlayers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pass saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving pass action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveAttackAction() async {
    if (_selectedPlayer == null) {
      return;
    }

    final team = widget.practice.team;

    // Normalize coordinates so first point is always on left half
    final normalizedCoords = _normalizeCoordinates(
      _startX,
      _startY,
      _endX,
      _endY,
    );

    // Create metadata map with result and selected metadata
    final metadata = <String, dynamic>{
      'result': _selectedAttackResult ?? 'unknown',
    };

    // Add selected metadata fields
    for (final metadataField in _selectedAttackMetadata) {
      metadata[metadataField] = true;
    }

    final tempEvent = Event(
      id: DateTime.now().millisecondsSinceEpoch,
      practice: widget.practice,
      match: null,
      player: _selectedPlayer!,
      team: team,
      type: EventType.attack,
      metadata: metadata,
      timestamp: DateTime.now(),
      fromX: normalizedCoords['fromX'],
      fromY: normalizedCoords['fromY'],
      toX: normalizedCoords['toX'],
      toY: normalizedCoords['toY'],
    );

    try {
      await _eventService.insertEvent(tempEvent);

      setState(() {
        _selectedPlayer = null;
        _selectedActionType = null;
        _selectedAttackResult = null;
        _selectedAttackMetadata.clear();
        _isRecordingCoordinates = false;
        _recordingAction = null;
        _hasStartPoint = false;
        _startX = null;
        _startY = null;
        _endX = null;
        _endY = null;
        _displayStartX = null;
        _displayStartY = null;
        _displayEndX = null;
        _displayEndY = null;
      });

      await _loadTeamPlayers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attack saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attack action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveFreeballAction() async {
    if (_selectedPlayer == null) {
      return;
    }

    final team = widget.practice.team;

    // Normalize coordinates so first point is always on left half
    final normalizedCoords = _normalizeCoordinates(
      _startX,
      _startY,
      _endX,
      _endY,
    );

    // Create metadata map with action
    final metadata = <String, dynamic>{
      'action': _selectedFreeballAction ?? 'unknown',
    };

    // Add result if selected (for received freeballs)
    if (_selectedFreeballResult != null) {
      metadata['result'] = _selectedFreeballResult;
    }

    final tempEvent = Event(
      id: DateTime.now().millisecondsSinceEpoch,
      practice: widget.practice,
      match: null,
      player: _selectedPlayer!,
      team: team,
      type: EventType.freeball,
      metadata: metadata,
      timestamp: DateTime.now(),
      fromX: normalizedCoords['fromX'],
      fromY: normalizedCoords['fromY'],
      toX: normalizedCoords['toX'],
      toY: normalizedCoords['toY'],
    );

    try {
      await _eventService.insertEvent(tempEvent);

      setState(() {
        _selectedPlayer = null;
        _selectedActionType = null;
        _selectedFreeballAction = null;
        _selectedFreeballResult = null;
        _isRecordingCoordinates = false;
        _recordingAction = null;
        _hasStartPoint = false;
        _startX = null;
        _startY = null;
        _endX = null;
        _endY = null;
        _displayStartX = null;
        _displayStartY = null;
        _displayEndX = null;
        _displayEndY = null;
      });

      await _loadTeamPlayers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Freeball saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving freeball action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _MiniCourtPainter extends CustomPainter {
  final double? fromX;
  final double? fromY;
  final double? toX;
  final double? toY;

  _MiniCourtPainter({this.fromX, this.fromY, this.toX, this.toY});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Court dimensions (mini version)
    final courtWidth = size.width;
    final courtHeight = size.height;

    // Draw court outline (end and side lines)
    canvas.drawRect(Rect.fromLTWH(0, 0, courtWidth, courtHeight), paint);

    // Draw net line (middle vertical)
    canvas.drawLine(
      Offset(courtWidth / 2, 0),
      Offset(courtWidth / 2, courtHeight),
      paint,
    );

    // Draw 10-foot lines (attack lines)
    // 10-foot lines are closer to the net (center) than the end lines
    final tenFootDistance =
        courtWidth * 0.15; // 15% from center (closer to net)

    // Left side 10-foot line (closer to net)
    canvas.drawLine(
      Offset(courtWidth / 2 - tenFootDistance, 0),
      Offset(courtWidth / 2 - tenFootDistance, courtHeight),
      paint,
    );

    // Right side 10-foot line (closer to net)
    canvas.drawLine(
      Offset(courtWidth / 2 + tenFootDistance, 0),
      Offset(courtWidth / 2 + tenFootDistance, courtHeight),
      paint,
    );

    // Draw coordinate points if available
    if (fromX != null && fromY != null) {
      final pointPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;

      // Convert normalized coordinates (0-1) to mini court position
      final x = fromX! * courtWidth;
      final y = fromY! * courtHeight;

      canvas.drawCircle(
        Offset(x.clamp(2, courtWidth - 2), y.clamp(2, courtHeight - 2)),
        2,
        pointPaint,
      );
    }

    if (toX != null && toY != null) {
      final pointPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

      // Convert normalized coordinates (0-1) to mini court position
      final x = toX! * courtWidth;
      final y = toY! * courtHeight;

      canvas.drawCircle(
        Offset(x.clamp(2, courtWidth - 2), y.clamp(2, courtHeight - 2)),
        2,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _MiniCourtPainter &&
        (oldDelegate.fromX != fromX ||
            oldDelegate.fromY != fromY ||
            oldDelegate.toX != toX ||
            oldDelegate.toY != toY);
  }
}
