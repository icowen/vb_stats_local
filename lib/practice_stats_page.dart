import 'package:flutter/material.dart';
import 'models/practice.dart';
import 'models/player.dart';
import 'models/event.dart';
import 'database_helper.dart';

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
      final teamPlayers = await _dbHelper.getTeamPlayers(
        widget.practice.team.id!,
      );
      final allPlayers = await _dbHelper.getAllPlayers();
      final teamEvents = await _dbHelper.getEventsForPractice(
        widget.practice.id!,
      );
      setState(() {
        _teamPlayers = teamPlayers;
        _allPlayers = allPlayers;
        _teamEvents = teamEvents;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading team players: $e');
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
                // Left Sidebar - Players List
                Container(
                  width: 300,
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
                        padding: const EdgeInsets.all(16.0),
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
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.practice.practiceTitle,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${widget.practice.date.day}/${widget.practice.date.month}/${widget.practice.date.year}',
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
                      // Add Player Button
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addPlayerToPractice,
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add Player'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      // Players List
                      Expanded(
                        child: _teamPlayers.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No players in this practice yet.\nTap "Add Player" to get started.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _teamPlayers.length,
                                itemBuilder: (context, index) {
                                  final player = _teamPlayers[index];
                                  final isSelected =
                                      _selectedPlayer?.id == player.id;
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    color: isSelected
                                        ? const Color(
                                            0xFF00E5FF,
                                          ).withOpacity(0.1)
                                        : null,
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.person,
                                        color: isSelected
                                            ? const Color(0xFF00E5FF)
                                            : const Color(0xFF00E5FF),
                                        size: 20,
                                      ),
                                      title: Text(
                                        player.fullName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? const Color(0xFF00E5FF)
                                              : null,
                                        ),
                                      ),
                                      subtitle: Text(
                                        player.jerseyDisplay,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected
                                              ? const Color(
                                                  0xFF00E5FF,
                                                ).withOpacity(0.8)
                                              : null,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        onPressed: () =>
                                            _removePlayerFromPractice(player),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        color: Colors.red,
                                        iconSize: 18,
                                      ),
                                      onTap: () => _selectPlayer(player),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                // Right Side - Stats Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Expanded(child: _buildPlayerStatsArea())],
                    ),
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Team Stats'),
          content: const Text('Team statistics will be displayed here.'),
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

  void _selectPlayer(Player player) async {
    setState(() {
      if (_selectedPlayer?.id == player.id) {
        // If clicking the same player, unselect them
        _selectedPlayer = null;
        _playerEvents = [];
        _selectedServeType = null; // Clear serve type selection
      } else {
        // Select the new player
        _selectedPlayer = player;
        _selectedServeType = null; // Clear serve type selection
      }
    });

    if (_selectedPlayer != null) {
      await _loadPlayerEvents();
    }
  }

  Future<void> _loadPlayerEvents() async {
    if (_selectedPlayer == null) return;

    try {
      final events = await _dbHelper.getEventsForPlayer(_selectedPlayer!.id!);
      setState(() {
        _playerEvents = events;
      });
    } catch (e) {
      print('Error loading player events: $e');
      setState(() {
        _playerEvents = [];
      });
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
                      : () {
                          setState(() {
                            _teamPlayers.add(player);
                          });
                          Navigator.of(context).pop();
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

  void _removePlayerFromPractice(Player player) {
    setState(() {
      _teamPlayers.removeWhere((p) => p.id == player.id);
      if (_selectedPlayer?.id == player.id) {
        _selectedPlayer = null;
      }
    });
  }

  Widget _buildPlayerStatsArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Groups (always show)
        Expanded(
          child: Column(
            children: [
              _buildServingStats(),
              const SizedBox(height: 8),
              _buildPassingStats(),
              const SizedBox(height: 8),
              _buildAttackingStats(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServingStats() {
    final servingStats = _getServingStats();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Serving', style: Theme.of(context).textTheme.titleMedium),
                if (_selectedPlayer != null) ...[
                  Text(
                    '${servingStats['float']! + servingStats['hybrid']! + servingStats['spin']!} serves | Float: ${servingStats['float']} | In: ${servingStats['in']} | Error: ${servingStats['error']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Serve Type Toggle
            Row(
              children: [
                Expanded(child: _buildToggleButton('Float', 'float')),
                const SizedBox(width: 4),
                Expanded(child: _buildToggleButton('Hybrid', 'hybrid')),
                const SizedBox(width: 4),
                Expanded(child: _buildToggleButton('Spin', 'spin')),
              ],
            ),
            const SizedBox(height: 8),
            // Serve Results
            Row(
              children: [
                Expanded(
                  child: _buildStatButton(
                    'Ace',
                    const Color(0xFF00FF88),
                    () => _recordServeResult('ace'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildStatButton(
                    'In',
                    const Color(0xFF00E5FF),
                    () => _recordServeResult('in'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildStatButton(
                    'Error',
                    const Color(0xFFFF4444),
                    () => _recordServeResult('error'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassingStats() {
    final passingStats = _getPassingStats();
    final passingAverage = _getPassingAverage();
    final totalPasses = passingStats.values.reduce((a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Passing', style: Theme.of(context).textTheme.titleMedium),
                if (_selectedPlayer != null) ...[
                  Text(
                    '$totalPasses attempts | ${passingAverage.toStringAsFixed(2)} avg | Ace: ${passingStats['ace']} | 1: ${passingStats['1']} | 2: ${passingStats['2']} | 3: ${passingStats['3']} | 0: ${passingStats['0']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatButton(
                    'Ace',
                    const Color(0xFF00FF88),
                    () => _recordPassRating('ace'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildStatButton(
                    '0',
                    const Color(0xFFFF4444),
                    () => _recordPassRating('0'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildStatButton(
                    '1',
                    const Color(0xFFFF8800),
                    () => _recordPassRating('1'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildStatButton(
                    '2',
                    const Color(0xFF00E5FF),
                    () => _recordPassRating('2'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildStatButton(
                    '3',
                    const Color(0xFF00FF88),
                    () => _recordPassRating('3'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttackingStats() {
    final attackingStats = _getAttackingStats();
    final totalAttacks = attackingStats.values.reduce((a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attacking',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_selectedPlayer != null) ...[
                  Text(
                    '$totalAttacks attacks | Kill: ${attackingStats['kill']} | In: ${attackingStats['in']} | Error: ${attackingStats['error']}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatButton(
                    'Kill',
                    const Color(0xFF00FF88),
                    () => _recordAttackResult('kill'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildStatButton(
                    'In',
                    const Color(0xFF00E5FF),
                    () => _recordAttackResult('in'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildStatButton(
                    'Error',
                    const Color(0xFFFF4444),
                    () => _recordAttackResult('error'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, String value) {
    final isDisabled = _selectedPlayer == null;
    final isSelected = _selectedServeType == value;
    final buttonColor = isDisabled
        ? Colors.grey
        : isSelected
        ? const Color(0xFF00E5FF)
        : const Color(0xFF00E5FF).withOpacity(0.5);

    return OutlinedButton(
      onPressed: isDisabled
          ? null
          : () {
              setState(() {
                _selectedServeType = isSelected ? null : value;
              });
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: buttonColor,
        side: BorderSide(color: buttonColor, width: isSelected ? 3 : 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: const Size(0, 32),
        backgroundColor: isSelected
            ? const Color(0xFF00E5FF).withOpacity(0.1)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: buttonColor,
        ),
      ),
    );
  }

  Widget _buildStatButton(String label, Color color, VoidCallback onPressed) {
    final isDisabled = _selectedPlayer == null;
    final buttonColor = isDisabled ? Colors.grey : color;

    return OutlinedButton(
      onPressed: isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: buttonColor,
        side: BorderSide(color: buttonColor, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: const Size(0, 32),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: buttonColor,
        ),
      ),
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
      await _loadPlayerEvents();
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
      await _loadPlayerEvents();
      await _loadTeamEvents();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded pass rating: $rating for ${_selectedPlayer!.fullName}',
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
      await _loadPlayerEvents();
      await _loadTeamEvents();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded attack: $result for ${_selectedPlayer!.fullName}',
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
    final eventsToUse = _selectedPlayer != null ? _playerEvents : _teamEvents;
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
    final eventsToUse = _selectedPlayer != null ? _playerEvents : _teamEvents;
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
    final eventsToUse = _selectedPlayer != null ? _playerEvents : _teamEvents;
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
    final eventsToUse = _selectedPlayer != null ? _playerEvents : _teamEvents;
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
}
