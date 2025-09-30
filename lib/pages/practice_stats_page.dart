import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import '../utils/app_colors.dart';
import '../providers/player_selection_provider.dart';
import '../providers/event_provider.dart';
import '../providers/settings_provider.dart';

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
  String? _selectedServeResult; // 'ace', 'in', 'error'
  String? _selectedPassRating; // 'ace', '3', '2', '1', '0'
  String? _selectedAttackResult; // 'kill', 'in', 'error'
  List<Event> _teamEvents = [];
  String? _selectedServeType;

  // Attack metadata selection (multiple selection)
  final Set<String> _selectedAttackMetadata = {};

  // Pass type selection (single selection)
  String? _selectedPassType;

  // Freeball action selection
  String? _selectedFreeballAction; // 'sent' or 'received'
  String? _selectedFreeballResult; // 'good' or 'bad' (for received only)

  // Blocking action selection
  String? _selectedBlockingType; // 'solo', 'assist', or 'error'

  // Dig action selection
  String? _selectedDigType; // 'overhand' or 'platform'

  // Set action selection
  String? _selectedSetType; // 'in_system' or 'out_of_system'

  // Caching system
  final Map<int, List<Event>> _playerEventsCache = {};

  // Court zones - 6 zones per side (2 columns × 3 rows)
  // Each side has zones 1-6 in a 2×3 grid
  Map<String, int?> _courtZones = {
    // Home side - 6 zones
    'home_1': null, 'home_2': null, 'home_3': null,
    'home_4': null, 'home_5': null, 'home_6': null,
    // Away side - 6 zones
    'away_1': null, 'away_2': null, 'away_3': null,
    'away_4': null, 'away_5': null, 'away_6': null,
  };

  // Court coordinate methods

  bool _cacheInitialized = false;

  // Undo/Redo system
  final List<UndoAction> _undoStack = [];
  final List<UndoAction> _redoStack = [];

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
          IconButton(
            onPressed: () => _showSettingsModal(context),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
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
              child: CircularProgressIndicator(color: AppColors.primary),
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
                            color: Colors.grey.withValues(alpha: 0.3),
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
                                      backgroundColor: AppColors.primary,
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
                                      backgroundColor: AppColors.secondary,
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
                                      final isOnCourt =
                                          player.id != null &&
                                          _isPlayerOnCourt(player.id!);
                                      final hasPlayersOnCourt =
                                          _hasAnyPlayersOnCourt();

                                      // Determine styling based on selection and court status
                                      Color? backgroundColor;
                                      Color borderColor;
                                      double opacity = 1.0;

                                      if (isSelected) {
                                        backgroundColor = const Color(
                                          0xFF00E5FF,
                                        ).withValues(alpha: 0.1);
                                        borderColor = AppColors.primary;
                                      } else if (hasPlayersOnCourt &&
                                          !isOnCourt) {
                                        // Players not on court when others are on court
                                        backgroundColor = null;
                                        borderColor = Colors.grey[400]!;
                                        opacity = 0.6;
                                      } else if (hasPlayersOnCourt &&
                                          isOnCourt) {
                                        // Players on court when others are also on court
                                        backgroundColor = null;
                                        borderColor = Colors.grey[600]!;
                                      } else {
                                        backgroundColor = null;
                                        borderColor = Colors.grey[300]!;
                                      }

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: backgroundColor,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: borderColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            // Select this player (like selecting an action)
                                            setState(() {
                                              _selectedPlayer = player;
                                            });
                                            // Also update the provider
                                            final selectionProvider = context
                                                .read<
                                                  PlayerSelectionProvider
                                                >();
                                            selectionProvider.selectPlayer(
                                              player,
                                            );
                                          },
                                          onLongPress: () =>
                                              _showRemovePlayerModal(player),
                                          onDoubleTap: () {
                                            if (_selectedPlayer?.id ==
                                                player.id) {
                                              // Double tap selected player to clear selection
                                              setState(() {
                                                _selectedPlayer = null;
                                              });
                                              // Also clear the provider
                                              final selectionProvider = context
                                                  .read<
                                                    PlayerSelectionProvider
                                                  >();
                                              selectionProvider
                                                  .clearPlayerSelection();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Player selection cleared',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 1,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Opacity(
                                            opacity: opacity,
                                            child: Container(
                                              width: double.infinity,
                                              height:
                                                  36, // Fixed height for short tiles
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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
                            color: Colors.grey.withValues(alpha: 0.3),
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

  void _showSettingsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.courtBackground,
          title: const Text('Settings', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stat Groups Visibility',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatGroupToggle(
                      context,
                      'Serve',
                      settings.serveVisible,
                      settings.toggleServeVisibility,
                      AppColors.primary,
                    ),
                    _buildStatGroupToggle(
                      context,
                      'Pass',
                      settings.passVisible,
                      settings.togglePassVisibility,
                      AppColors.secondary,
                    ),
                    _buildStatGroupToggle(
                      context,
                      'Attack',
                      settings.attackVisible,
                      settings.toggleAttackVisibility,
                      AppColors.orangeWarning,
                    ),
                    _buildStatGroupToggle(
                      context,
                      'Block',
                      settings.blockVisible,
                      settings.toggleBlockVisibility,
                      AppColors.redError,
                    ),
                    _buildStatGroupToggle(
                      context,
                      'Dig',
                      settings.digVisible,
                      settings.toggleDigVisibility,
                      AppColors.primary,
                    ),
                    _buildStatGroupToggle(
                      context,
                      'Set',
                      settings.setVisible,
                      settings.toggleSetVisibility,
                      AppColors.secondary,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await settings.resetToDefaults();
                          },
                          child: const Text(
                            'Reset to Defaults',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatGroupToggle(
    BuildContext context,
    String title,
    bool isVisible,
    VoidCallback onToggle,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
          Switch(
            value: isVisible,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey[600],
            inactiveTrackColor: Colors.grey[800],
          ),
        ],
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
                  leading: const Icon(Icons.person, color: AppColors.primary),
                  title: Text(player.fullName),
                  subtitle: Text(player.jerseyDisplay),
                  trailing: isAlreadyAdded
                      ? const Icon(Icons.check, color: Colors.green)
                      : const Icon(Icons.add, color: AppColors.secondary),
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

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${player.fullName} added to practice',
                                  ),
                                  backgroundColor: AppColors.secondary,
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error adding player to practice: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding player: $e'),
                                  backgroundColor: AppColors.redError,
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
                  child: CircularProgressIndicator(color: AppColors.primary),
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
                        color: AppColors.secondary,
                      ),
                      title: Text(team.teamName),
                      subtitle: Text('${team.clubName} - ${team.age}U'),
                      trailing: const Icon(Icons.add, color: AppColors.primary),
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
                                backgroundColor: AppColors.secondary,
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error adding team to practice: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error adding team: $e'),
                                backgroundColor: AppColors.redError,
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${player.fullName} removed from practice'),
            backgroundColor: AppColors.orangeWarning,
          ),
        );
      }
    } catch (e) {
      print('Error removing player from practice: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing player: $e'),
            backgroundColor: AppColors.redError,
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
          onCourtDoubleTap: _onCourtLongPress,
          onClear: _clearCoordinates,
          startX: _displayStartX,
          startY: _displayStartY,
          endX: _displayEndX,
          endY: _displayEndY,
          hasStartPoint: _hasStartPoint,
          selectedAction: _recordingAction,
          isRecording:
              true, // Always allow court taps - _onCourtTap handles the logic
          courtZones: _courtZones,
          onZoneTap: _onZoneTap,
          onZoneLongPress: _onZoneLongPress,
          teamPlayers: _teamPlayers,
          selectedZone: null, // No zone selection in unified workflow
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
            ? AppColors.secondary
            : result == 'in'
            ? AppColors.primary
            : AppColors.redError;
        eventIcon = Icons.sports_volleyball;
        break;
      case EventType.pass:
        final rating = event.metadata['rating'] as String?;
        eventDescription = 'Pass rating: ${rating ?? 'Unknown'}';
        eventColor = rating == 'ace' || rating == '3'
            ? AppColors.secondary
            : rating == '2'
            ? AppColors.primary
            : rating == '1'
            ? AppColors.orangeWarning
            : AppColors.redError;
        eventIcon = Icons.handshake;
        break;
      case EventType.attack:
        final result = event.metadata['result'] as String?;
        eventDescription = 'Attack: ${result ?? 'Unknown'}';
        eventColor = result == 'kill'
            ? AppColors.secondary
            : result == 'in'
            ? AppColors.primary
            : AppColors.redError;
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
                style: TextStyle(color: AppColors.primary),
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
                    backgroundColor: AppColors.primary,
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
      case 'block':
        return _buildBlockingForm(formData, setModalState);
      case 'dig':
        return _buildDigForm(formData, setModalState);
      case 'set':
        return _buildSetForm(formData, setModalState);
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

  Widget _buildBlockingForm(
    Map<String, dynamic> formData,
    StateSetter setModalState,
  ) {
    final type = formData['type'] as String? ?? 'solo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Blocking Type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                'Solo',
                'solo',
                type == 'solo',
                () => setModalState(() => formData['type'] = 'solo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'Assist',
                'assist',
                type == 'assist',
                () => setModalState(() => formData['type'] = 'assist'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'Error',
                'error',
                type == 'error',
                () => setModalState(() => formData['type'] = 'error'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigForm(
    Map<String, dynamic> formData,
    StateSetter setModalState,
  ) {
    final type = formData['type'] as String? ?? 'overhand';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dig Type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                'Overhand',
                'overhand',
                type == 'overhand',
                () => setModalState(() => formData['type'] = 'overhand'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'Platform',
                'platform',
                type == 'platform',
                () => setModalState(() => formData['type'] = 'platform'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSetForm(
    Map<String, dynamic> formData,
    StateSetter setModalState,
  ) {
    final type = formData['type'] as String? ?? 'in_system';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set Type', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildToggleButton(
                'In System',
                'in_system',
                type == 'in_system',
                () => setModalState(() => formData['type'] = 'in_system'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildToggleButton(
                'Out of System',
                'out_of_system',
                type == 'out_of_system',
                () => setModalState(() => formData['type'] = 'out_of_system'),
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
            color: isSelected ? AppColors.primary : Colors.grey,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppColors.primary : Colors.grey,
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event updated successfully'),
            backgroundColor: AppColors.secondary,
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating event: $e'),
            backgroundColor: AppColors.redError,
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Undone: ${action.description}'),
            backgroundColor: AppColors.primary,
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error undoing action: $e'),
            backgroundColor: AppColors.redError,
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redone: ${action.description}'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      print('Error redoing action: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error redoing action: $e'),
            backgroundColor: AppColors.redError,
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event deleted successfully'),
            backgroundColor: AppColors.secondary,
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting event: $e'),
            backgroundColor: AppColors.redError,
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

  Map<String, int> _getPlayerBlockingStats(List<Event> playerEvents) {
    final blockEvents = playerEvents
        .where((e) => e.type == EventType.block)
        .toList();
    final stats = <String, int>{'solo': 0, 'assist': 0, 'error': 0, 'total': 0};

    for (final event in blockEvents) {
      final type = event.metadata['type'] as String?;
      stats['total'] = (stats['total'] ?? 0) + 1;
      if (type != null && stats.containsKey(type)) {
        stats[type] = (stats[type] ?? 0) + 1;
      }
    }

    return stats;
  }

  Map<String, int> _getPlayerDigStats(List<Event> playerEvents) {
    final digEvents = playerEvents
        .where((e) => e.type == EventType.dig)
        .toList();
    final stats = <String, int>{'overhand': 0, 'platform': 0, 'total': 0};

    for (final event in digEvents) {
      final type = event.metadata['type'] as String?;
      stats['total'] = (stats['total'] ?? 0) + 1;
      if (type != null && stats.containsKey(type)) {
        stats[type] = (stats[type] ?? 0) + 1;
      }
    }

    return stats;
  }

  Map<String, int> _getPlayerSetStats(List<Event> playerEvents) {
    final setEvents = playerEvents
        .where((e) => e.type == EventType.set)
        .toList();
    final stats = <String, int>{'in_system': 0, 'out_of_system': 0, 'total': 0};

    for (final event in setEvents) {
      final type = event.metadata['type'] as String?;
      stats['total'] = (stats['total'] ?? 0) + 1;
      if (type != null && stats.containsKey(type)) {
        stats[type] = (stats[type] ?? 0) + 1;
      }
    }

    return stats;
  }

  void _onZoneTap(String zoneKey) {
    final selectionProvider = context.read<PlayerSelectionProvider>();
    final selectedPlayer = selectionProvider.selectedPlayer;
    final selectedActionType = selectionProvider.selectedActionType;

    // Only assign player to zone if player is selected but no action is selected
    if (selectedPlayer != null && selectedActionType == null) {
      // Player selected but no action - assign to this zone
      _assignPlayerToZone(selectedPlayer, zoneKey);
    }
    // If action is also selected, don't assign to zone - coordinate recording takes precedence
  }

  void _onZoneLongPress(String zoneKey) {
    // Clear the zone by creating a new map
    setState(() {
      _courtZones = Map<String, int?>.from(_courtZones);
      _courtZones[zoneKey] = null;
    });
  }

  void _assignPlayerToZone(Player player, String zoneKey) {
    setState(() {
      // Create a new map to ensure proper repainting
      _courtZones = Map<String, int?>.from(_courtZones);

      // Remove player from any other zone first
      for (String key in _courtZones.keys) {
        if (_courtZones[key] == player.id) {
          _courtZones[key] = null;
        }
      }
      // Assign player to selected zone
      _courtZones[zoneKey] = player.id;
      // Clear player selection
      _selectedPlayer = null;
    });
  }

  bool _isPlayerOnCourt(int playerId) {
    return _courtZones.values.contains(playerId);
  }

  bool _hasAnyPlayersOnCourt() {
    return _courtZones.values.any((playerId) => playerId != null);
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
      // Blocking columns
      'Blocks': 60.0,
      'Solo': 50.0,
      'Assist': 50.0,
      'Error': 50.0,
      // Dig columns
      'Digs': 50.0,
      'Overhand': 70.0,
      'Platform': 70.0,
      // Set columns
      'Sets': 50.0,
      'In System': 70.0,
      'Out of System': 90.0,
    };

    return PlayerStatsTable(
      columnWidths: columnWidths,
      teamPlayers: _teamPlayers,
      teamEvents: _teamEvents,
      getPlayerServingStats: _getPlayerServingStats,
      getPlayerPassingStats: _getPlayerPassingStats,
      getPlayerAttackingStats: _getPlayerAttackingStats,
      getPlayerBlockingStats: _getPlayerBlockingStats,
      getPlayerDigStats: _getPlayerDigStats,
      getPlayerSetStats: _getPlayerSetStats,
    );
  }

  Widget _buildAllActionsTile() {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              children: [
                Column(children: _buildStatGroupRows(settings)),
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
      },
    );
  }

  List<Widget> _buildStatGroupRows(SettingsProvider settings) {
    List<Widget> rows = [];
    List<Widget> currentRow = [];

    // Helper function to add a stat group to current row
    void addStatGroup(Widget statGroup) {
      currentRow.add(statGroup);
      if (currentRow.length == 2) {
        rows.add(IntrinsicHeight(child: Row(children: currentRow)));
        rows.add(const SizedBox(height: 4));
        currentRow = [];
      }
    }

    // Add stat groups based on visibility settings
    if (settings.serveVisible) {
      addStatGroup(_buildServeColumn());
    }
    if (settings.passVisible) {
      addStatGroup(_buildPassColumn());
    }
    if (settings.attackVisible) {
      addStatGroup(_buildAttackColumn());
    }
    if (settings.blockVisible) {
      addStatGroup(_buildBlockColumn());
    }
    if (settings.digVisible) {
      addStatGroup(_buildDigColumn());
    }
    if (settings.setVisible) {
      addStatGroup(_buildSetColumn());
    }

    // Add any remaining items in current row
    if (currentRow.isNotEmpty) {
      rows.add(IntrinsicHeight(child: Row(children: currentRow)));
    }

    return rows;
  }

  Widget _buildServeColumn() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 2),
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
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text(
                  'SERVE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
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
                      AppColors.primary,
                      () => _selectServeType('float'),
                      _selectedServeType == 'float',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'Hybrid',
                      AppColors.primary,
                      () => _selectServeType('hybrid'),
                      _selectedServeType == 'hybrid',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'Spin',
                      AppColors.primary,
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
                      AppColors.secondary,
                      () => _selectServeResult('ace'),
                      _selectedServeResult == 'ace',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'In',
                      AppColors.secondary,
                      () => _selectServeResult('in'),
                      _selectedServeResult == 'in',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'Error',
                      AppColors.redError,
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
    );
  }

  Widget _buildPassColumn() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.secondary, width: 2),
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
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text(
                  'PASS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondary,
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
                      AppColors.secondary,
                      () => _selectPassRating('ace'),
                      _selectedPassRating == 'ace',
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: _buildCompactButton(
                      '3',
                      AppColors.secondary,
                      () => _selectPassRating('3'),
                      _selectedPassRating == '3',
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: _buildCompactButton(
                      '2',
                      AppColors.primary,
                      () => _selectPassRating('2'),
                      _selectedPassRating == '2',
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: _buildCompactButton(
                      '1',
                      AppColors.orangeWarning,
                      () => _selectPassRating('1'),
                      _selectedPassRating == '1',
                    ),
                  ),
                  const SizedBox(width: 1),
                  Expanded(
                    child: _buildCompactButton(
                      '0',
                      AppColors.redError,
                      () => _selectPassRating('0'),
                      _selectedPassRating == '0',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Pass Type
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPassTypeButton(
                    'Overhand',
                    'overhand',
                    AppColors.secondary,
                  ),
                  _buildPassTypeButton(
                    'Platform',
                    'platform',
                    AppColors.secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttackColumn() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.orangeWarning, width: 2),
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
                padding: const EdgeInsets.symmetric(vertical: 2),
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
                      AppColors.secondary,
                      () => _selectAttackResult('kill'),
                      _selectedAttackResult == 'kill',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'In',
                      AppColors.primary,
                      () => _selectAttackResult('in'),
                      _selectedAttackResult == 'in',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'Error',
                      AppColors.redError,
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
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
    );
  }

  Widget _buildBlockColumn() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFF6B6B), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              // Blocking Title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text(
                  'BLOCKING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Blocking Types
              Row(
                children: [
                  Expanded(
                    child: _buildCompactButton(
                      'Solo',
                      const Color(0xFFFF6B6B),
                      () => _selectBlockingType('solo'),
                      _selectedBlockingType == 'solo',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'Assist',
                      const Color(0xFFFF6B6B),
                      () => _selectBlockingType('assist'),
                      _selectedBlockingType == 'assist',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'Error',
                      const Color(0xFFFF6B6B),
                      () => _selectBlockingType('error'),
                      _selectedBlockingType == 'error',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigColumn() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF4CAF50), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              // Dig Title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text(
                  'DIG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Dig Types
              Row(
                children: [
                  Expanded(
                    child: _buildCompactButton(
                      'Overhand',
                      const Color(0xFF4CAF50),
                      () => _selectDigType('overhand'),
                      _selectedDigType == 'overhand',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'Platform',
                      const Color(0xFF4CAF50),
                      () => _selectDigType('platform'),
                      _selectedDigType == 'platform',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetColumn() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF2196F3), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              // Set Title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text(
                  'SET',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Set Types
              Row(
                children: [
                  Expanded(
                    child: _buildCompactButton(
                      'In System',
                      const Color(0xFF2196F3),
                      () => _selectSetType('in_system'),
                      _selectedSetType == 'in_system',
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _buildCompactButton(
                      'Out of System',
                      const Color(0xFF2196F3),
                      () => _selectSetType('out_of_system'),
                      _selectedSetType == 'out_of_system',
                    ),
                  ),
                ],
              ),
            ],
          ),
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
            ? buttonColor.withValues(alpha: 0.2)
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
            ? buttonColor.withValues(alpha: 0.3)
            : Colors.transparent,
        side: BorderSide(
          color: isDisabled
              ? Colors.grey
              : (isSelected ? buttonColor : buttonColor.withValues(alpha: 0.5)),
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
            ? buttonColor.withValues(alpha: 0.3)
            : Colors.transparent,
        side: BorderSide(
          color: isDisabled
              ? Colors.grey
              : (isSelected ? buttonColor : buttonColor.withValues(alpha: 0.5)),
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
        child: const Center(
          child: Icon(Icons.location_off, size: 16, color: Colors.grey),
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
    if (_selectedBlockingType != null) {
      return true;
    }
    if (_selectedDigType != null) {
      return true;
    }
    if (_selectedSetType != null) {
      return true;
    }

    return false;
  }

  Color _getSaveButtonColor() {
    if (_selectedServeType != null || _selectedServeResult != null) {
      return AppColors.primary; // Blue for serve
    }
    if (_selectedPassRating != null) {
      return AppColors.secondary; // Green for pass
    }
    if (_selectedAttackResult != null) {
      return AppColors.orangeWarning; // Orange for attack
    }
    if (_selectedFreeballAction != null) {
      return const Color(0xFF9C27B0); // Purple for freeball
    }
    if (_selectedBlockingType != null) {
      return const Color(0xFFFF6B6B); // Red for blocking
    }
    if (_selectedDigType != null) {
      return const Color(0xFF4CAF50); // Green for dig
    }
    if (_selectedSetType != null) {
      return const Color(0xFF2196F3); // Blue for set
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
    if (_selectedBlockingType != null) {
      return 'Save Block';
    }
    if (_selectedDigType != null) {
      return 'Save Dig';
    }
    if (_selectedSetType != null) {
      return 'Save Set';
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
    } else if (_selectedBlockingType != null) {
      _saveBlockingAction();
    } else if (_selectedDigType != null) {
      _saveDigAction();
    } else if (_selectedSetType != null) {
      _saveSetAction();
    }
  }

  void _selectServeType(String type) {
    // Use provider for serve type selection
    final selectionProvider = context.read<PlayerSelectionProvider>();
    selectionProvider.selectActionType('serve');
    selectionProvider.selectServeType(type);

    // Keep local state for backward compatibility
    setState(() {
      _selectedServeType = type;
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
        _selectedServeType = null;
        _selectedServeResult = null;
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Serve saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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
    // Use provider for serve result selection
    final selectionProvider = context.read<PlayerSelectionProvider>();
    selectionProvider.selectActionType('serve');
    selectionProvider.selectServeResult(result);

    // Keep local state for backward compatibility
    setState(() {
      _selectedServeResult = result;
    });
  }

  void _selectPassRating(String rating) {
    // Use provider for pass rating selection
    final selectionProvider = context.read<PlayerSelectionProvider>();
    selectionProvider.selectActionType('pass');
    selectionProvider.selectPassRating(rating);

    // Keep local state for backward compatibility
    setState(() {
      _selectedPassRating = rating;
    });
  }

  void _selectAttackResult(String result) {
    // Use provider for attack result selection
    final selectionProvider = context.read<PlayerSelectionProvider>();
    selectionProvider.selectActionType('attack');
    selectionProvider.selectAttackResult(result);

    // Keep local state for backward compatibility
    setState(() {
      _selectedAttackResult = result;
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

  void _selectBlockingType(String type) {
    setState(() {
      // Clear other action selections
      _selectedServeType = null;
      _selectedServeResult = null;
      _selectedPassRating = null;
      _selectedPassType = null;
      _selectedAttackResult = null;
      _selectedAttackMetadata.clear();
      _selectedFreeballAction = null;
      _selectedFreeballResult = null;
      _selectedDigType = null;

      // Set blocking type
      _selectedBlockingType = type;
    });
  }

  void _selectDigType(String type) {
    setState(() {
      // Clear other action selections
      _selectedServeType = null;
      _selectedServeResult = null;
      _selectedPassRating = null;
      _selectedPassType = null;
      _selectedAttackResult = null;
      _selectedAttackMetadata.clear();
      _selectedFreeballAction = null;
      _selectedFreeballResult = null;
      _selectedBlockingType = null;

      // Set dig type
      _selectedDigType = type;
    });
  }

  void _selectSetType(String type) {
    setState(() {
      // Clear other action selections
      _selectedServeType = null;
      _selectedServeResult = null;
      _selectedPassRating = null;
      _selectedPassType = null;
      _selectedAttackResult = null;
      _selectedAttackMetadata.clear();
      _selectedFreeballAction = null;
      _selectedFreeballResult = null;
      _selectedBlockingType = null;
      _selectedDigType = null;

      // Set set type
      _selectedSetType = type;
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

  void _onCourtTap(double x, double y) {
    print('🎯 _onCourtTap called with coordinates: ($x, $y)');
    final selectionProvider = context.read<PlayerSelectionProvider>();
    final selectedPlayer = selectionProvider.selectedPlayer;
    final selectedActionType = selectionProvider.selectedActionType;
    print(
      '🎯 Selected player: ${selectedPlayer?.fullName}, Action: $selectedActionType',
    );

    // Check if both player and action are selected
    if (selectedPlayer != null && selectedActionType != null) {
      // Record coordinates for action
      setState(() {
        if (!_hasStartPoint) {
          // First tap - set start point
          _displayStartX = x;
          _displayStartY = y;
          _hasStartPoint = true;
        } else if (_endX == null || _endY == null) {
          // Second tap - set end point and save the event
          _displayEndX = x;
          _displayEndY = y;
          // Don't reset _hasStartPoint here - keep both points visible until saved

          // Save the event with coordinates
          _saveEventWithCoordinates();
        } else {
          // We already have both points - update the end point
          _displayEndX = x;
          _displayEndY = y;
        }

        // Store display coordinates directly (no flipping for display)
        _startX = _displayStartX;
        _startY = _displayStartY;
        _endX = _displayEndX;
        _endY = _displayEndY;
      });
    } else if (selectedPlayer != null && selectedActionType == null) {
      // Only player selected - this should be handled by zone assignment logic
      // The zone assignment logic is already in the volleyball court widget
      return;
    } else {
      // No player selected - just record coordinates for display
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
  }

  void _onCourtLongPress(double x, double y) {
    print('🎯🎯 _onCourtLongPress called with coordinates: ($x, $y)');
    print(
      '🎯🎯 Current state - hasStartPoint: $_hasStartPoint, start=($_startX, $_startY), end=($_endX, $_endY)',
    );
    final selectionProvider = context.read<PlayerSelectionProvider>();
    final selectedPlayer = selectionProvider.selectedPlayer;
    final selectedActionType = selectionProvider.selectedActionType;
    print(
      '🎯🎯 Selected player: ${selectedPlayer?.fullName}, Action: $selectedActionType',
    );

    // Only handle long press if we have both player and action selected
    if (selectedPlayer != null && selectedActionType != null) {
      print('🎯🎯 Processing long press - hasStartPoint: $_hasStartPoint');
      bool shouldSaveAfterUpdate = false;
      setState(() {
        if (!_hasStartPoint) {
          // No start point yet, treat as first tap
          print('🎯🎯 BRANCH 1: Setting start point');
          _displayStartX = x;
          _displayStartY = y;
          _hasStartPoint = true;
        } else if (_endX == null || _endY == null) {
          // We have a start point but no end point, so double tap should save the action
          print('🎯🎯 BRANCH 2: Setting end point and saving action');
          print('🎯🎯 BRANCH 2: _endX=$_endX, _endY=$_endY');
          print(
            '🎯🎯 BRANCH 2: Start coords=($_startX, $_startY), New end coords=($x, $y)',
          );
          // Use tolerance-based comparison for floating point coordinates
          const double tolerance = 0.01; // 1% tolerance
          final startXDiff = (_startX ?? 0) - x;
          final startYDiff = (_startY ?? 0) - y;
          final isSameLocation =
              startXDiff.abs() < tolerance && startYDiff.abs() < tolerance;

          if (isSameLocation) {
            print(
              '🎯🎯 WARNING: Start and end coordinates are the same - you tapped and double-tapped at the same location',
            );
            print(
              '🎯🎯 Coordinate diff: startX=${startXDiff.toStringAsFixed(6)}, startY=${startYDiff.toStringAsFixed(6)}',
            );
          } else {
            print(
              '🎯🎯 SUCCESS: Start and end coordinates are different - double-tap at different location',
            );
            print(
              '🎯🎯 Coordinate diff: startX=${startXDiff.toStringAsFixed(6)}, startY=${startYDiff.toStringAsFixed(6)}',
            );
          }
          _displayEndX = x;
          _displayEndY = y;
          // Don't reset _hasStartPoint here - keep both points visible until saved

          // Will save after setState completes
          shouldSaveAfterUpdate = true;
        } else {
          // We already have both points - update the end point and save
          print('🎯🎯 BRANCH 3: Updating end point and saving action');
          print('🎯🎯 BRANCH 3: _endX=$_endX, _endY=$_endY');
          print(
            '🎯🎯 Before update - start=($_displayStartX, $_displayStartY), end=($_displayEndX, $_displayEndY)',
          );
          _displayEndX = x;
          _displayEndY = y;
          print(
            '🎯🎯 After update - start=($_displayStartX, $_displayStartY), end=($_displayEndX, $_displayEndY)',
          );

          // Will save after setState completes
          shouldSaveAfterUpdate = true;
        }

        // Store display coordinates directly (no flipping for display)
        _startX = _displayStartX;
        _startY = _displayStartY;
        _endX = _displayEndX;
        _endY = _displayEndY;
        print(
          '🎯🎯 Final stored coordinates - start=($_startX, $_startY), end=($_endX, $_endY)',
        );
      });

      // Save the event after setState completes if we updated the end point
      if (shouldSaveAfterUpdate) {
        print('🎯🎯 Calling _saveEventWithCoordinates after setState');
        _saveEventWithCoordinates();
      } else {
        print(
          '🎯🎯 Not calling _saveEventWithCoordinates - shouldSaveAfterUpdate: $shouldSaveAfterUpdate',
        );
      }
    } else {
      print('🎯🎯 Double tap ignored - missing player or action');
    }
  }

  void _saveEventWithCoordinates() async {
    final selectionProvider = context.read<PlayerSelectionProvider>();
    final selectedPlayer = selectionProvider.selectedPlayer;
    final selectedActionType = selectionProvider.selectedActionType;

    print(
      '💾 _saveEventWithCoordinates called with coordinates: start=($_startX, $_startY), end=($_endX, $_endY)',
    );

    if (selectedPlayer == null ||
        selectedActionType == null ||
        _startX == null ||
        _startY == null ||
        _endX == null ||
        _endY == null) {
      print('💾 _saveEventWithCoordinates aborted - missing data');
      return;
    }

    try {
      final eventProvider = context.read<EventProvider>();

      // Create metadata map with coordinates
      final metadata = <String, dynamic>{
        'startX': _startX,
        'startY': _startY,
        'endX': _endX,
        'endY': _endY,
      };

      // Add action-specific metadata
      switch (selectedActionType) {
        case 'serve':
          if (selectionProvider.selectedServeResult != null) {
            metadata['result'] = selectionProvider.selectedServeResult;
          }
          if (selectionProvider.selectedServeType != null) {
            metadata['serveType'] = selectionProvider.selectedServeType;
          }
          break;
        case 'pass':
          if (selectionProvider.selectedPassRating != null) {
            metadata['rating'] = selectionProvider.selectedPassRating;
          }
          if (selectionProvider.selectedPassType != null) {
            metadata['passType'] = selectionProvider.selectedPassType;
          }
          break;
        case 'attack':
          if (selectionProvider.selectedAttackResult != null) {
            metadata['result'] = selectionProvider.selectedAttackResult;
          }
          if (selectionProvider.selectedAttackMetadata.isNotEmpty) {
            metadata.addAll(
              Map.fromEntries(
                selectionProvider.selectedAttackMetadata.map(
                  (key) => MapEntry(key, true),
                ),
              ),
            );
          }
          break;
        case 'freeball':
          if (selectionProvider.selectedFreeballAction != null) {
            metadata['action'] = selectionProvider.selectedFreeballAction;
          }
          if (selectionProvider.selectedFreeballResult != null) {
            metadata['result'] = selectionProvider.selectedFreeballResult;
          }
          break;
        case 'block':
          if (selectionProvider.selectedBlockingType != null) {
            metadata['type'] = selectionProvider.selectedBlockingType;
          }
          break;
        case 'dig':
          if (selectionProvider.selectedDigType != null) {
            metadata['type'] = selectionProvider.selectedDigType;
          }
          break;
        case 'set':
          if (selectionProvider.selectedSetType != null) {
            metadata['type'] = selectionProvider.selectedSetType;
          }
          break;
      }

      // Get team information
      if (selectedPlayer.teamId == null) {
        throw Exception(
          'Player ${selectedPlayer.fullName} has no team assigned',
        );
      }
      final team = await _teamService.getTeam(selectedPlayer.teamId!);
      if (team == null) {
        throw Exception('Team not found for player ${selectedPlayer.fullName}');
      }

      // Create and save the event
      final event = Event(
        practice: widget.practice,
        player: selectedPlayer,
        team: team,
        type: EventType.values.firstWhere((e) => e.name == selectedActionType),
        metadata: metadata,
        timestamp: DateTime.now(),
        fromX: _startX,
        fromY: _startY,
        toX: _endX,
        toY: _endY,
      );

      await eventProvider.addEvent(event);

      // Update events history immediately
      setState(() {
        _teamEvents.add(event);
        if (_selectedPlayer != null && event.player.id == _selectedPlayer!.id) {
          _playerEvents.add(event);
        }
      });

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selectedActionType.toUpperCase()} event saved for ${selectedPlayer.fullName}',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Clear coordinates after successful save
      _clearCoordinates();
    } catch (e) {
      print('Error saving event: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving event: $e')));
      }
    }
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
        _selectedPassRating = null;
        _selectedPassType = null;
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pass saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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
        _selectedAttackResult = null;
        _selectedAttackMetadata.clear();
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attack saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
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
        _selectedFreeballAction = null;
        _selectedFreeballResult = null;
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Freeball saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving freeball action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveBlockingAction() async {
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

    // Create metadata map with blocking type
    final metadata = <String, dynamic>{
      'type': _selectedBlockingType ?? 'unknown',
    };

    final tempEvent = Event(
      id: DateTime.now().millisecondsSinceEpoch,
      practice: widget.practice,
      match: null,
      player: _selectedPlayer!,
      team: team,
      type: EventType.block,
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
        _selectedBlockingType = null;
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Block saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving blocking action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveDigAction() async {
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

    // Create metadata map with dig type
    final metadata = <String, dynamic>{'type': _selectedDigType ?? 'unknown'};

    final tempEvent = Event(
      id: DateTime.now().millisecondsSinceEpoch,
      practice: widget.practice,
      match: null,
      player: _selectedPlayer!,
      team: team,
      type: EventType.dig,
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
        _selectedDigType = null;
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dig saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving dig action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _saveSetAction() async {
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

    // Create metadata map with set type
    final metadata = <String, dynamic>{'type': _selectedSetType ?? 'unknown'};

    final tempEvent = Event(
      id: DateTime.now().millisecondsSinceEpoch,
      practice: widget.practice,
      match: null,
      player: _selectedPlayer!,
      team: team,
      type: EventType.set,
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
        _selectedSetType = null;
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set saved for ${tempEvent.player.firstName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving set action: $e'),
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
