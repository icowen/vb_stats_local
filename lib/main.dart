import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'models/player.dart';
import 'models/team.dart';
import 'models/match.dart';
import 'models/practice.dart';
import 'pages/practice_stats_page.dart';
import 'utils/date_utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00E5FF), // Neon light blue
          secondary: const Color(0xFF00FF88), // Neon light green
          surface: const Color(0xFF121212),
          background: const Color(0xFF000000),
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00E5FF)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00E5FF), width: 2),
          ),
          labelStyle: TextStyle(color: Color(0xFF00E5FF)),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF1E1E1E)),
          ),
        ),
      ),
      home: const MyHomePage(title: 'Volleyball Stats'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Player> _players = [];
  List<Team> _teams = [];
  List<Match> _matches = [];
  List<Practice> _practices = [];
  bool _isLoading = true;
  String? _expandedTile;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      await _dbHelper.ensureTablesExist();
      await _loadData();
    } catch (e) {
      print('Error initializing database: $e');
      setState(() {
        _players = [];
        _teams = [];
        _matches = [];
        _practices = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      // Ensure database is initialized before loading data
      await _dbHelper.database;

      final players = await _dbHelper.getAllPlayers();
      final teams = await _dbHelper.getAllTeams();
      final matches = await _dbHelper.getAllMatches();
      final practices = await _dbHelper.getAllPractices();

      setState(() {
        _players = players;
        _teams = teams;
        _matches = matches;
        _practices = practices;
        _isLoading = false;
      });
    } catch (e) {
      // Handle database initialization errors
      print('Error loading data: $e');
      setState(() {
        _players = [];
        _teams = [];
        _matches = [];
        _practices = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () => _showResetDatabaseDialog(context),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Database',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Dashboard Tiles Row
                  SizedBox(
                    height: 100,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTile(
                            'Players',
                            Icons.people,
                            Color(0xFF00E5FF),
                            _players.length,
                            () => _toggleExpanded('players'),
                            () => _showCreatePlayerModal(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTile(
                            'Teams',
                            Icons.groups,
                            Color(0xFF00FF88),
                            _teams.length,
                            () => _toggleExpanded('teams'),
                            () => _showCreateTeamModal(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTile(
                            'Matches',
                            Icons.sports_volleyball,
                            Color(0xFF00E5FF),
                            _matches.length,
                            () => _toggleExpanded('matches'),
                            () => _showCreateMatchModal(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTile(
                            'Practices',
                            Icons.fitness_center,
                            Color(0xFF00FF88),
                            _practices.length,
                            () => _toggleExpanded('practices'),
                            () => _showCreatePracticeModal(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Expanded Content Area
                  Expanded(child: _buildExpandedContent()),
                ],
              ),
            ),
    );
  }

  void _toggleExpanded(String tileName) {
    setState(() {
      _expandedTile = _expandedTile == tileName ? null : tileName;
    });
  }

  Widget _buildTile(
    String title,
    IconData icon,
    Color color,
    int count,
    VoidCallback onTap,
    VoidCallback onAdd,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.add, size: 16, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    if (_expandedTile == null) {
      return const Center(
        child: Text(
          'Select a category above to view items',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    switch (_expandedTile) {
      case 'players':
        return _buildPlayersList();
      case 'teams':
        return _buildTeamsList();
      case 'matches':
        return _buildMatchesList();
      case 'practices':
        return _buildPracticesList();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPlayersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Players (${_players.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _players.isEmpty
              ? const Center(child: Text('No players yet. Tap + to add one!'))
              : ListView.builder(
                  itemCount: _players.length,
                  itemBuilder: (context, index) {
                    final player = _players[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: Color(0xFF00E5FF),
                        ),
                        title: Text(player.fullName),
                        subtitle: Text(player.jerseyDisplay),
                        onTap: () => _showEditPlayerModal(context, player),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _showEditPlayerModal(context, player),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeamsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teams (${_teams.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _teams.isEmpty
              ? const Center(child: Text('No teams yet. Tap + to add one!'))
              : ListView.builder(
                  itemCount: _teams.length,
                  itemBuilder: (context, index) {
                    final team = _teams[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.groups,
                          color: Color(0xFF00FF88),
                        ),
                        title: Text(team.teamName),
                        subtitle: Text('${team.clubName} - Age ${team.age}'),
                        onTap: () => _showEditTeamModal(context, team),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditTeamModal(context, team),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMatchesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Matches (${_matches.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _matches.isEmpty
              ? const Center(child: Text('No matches yet. Tap + to add one!'))
              : ListView.builder(
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final match = _matches[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.sports_volleyball,
                          color: Color(0xFF00E5FF),
                        ),
                        title: Text(match.matchTitle),
                        subtitle: Text(
                          '${match.startTime?.day}/${match.startTime?.month}/${match.startTime?.year} at ${match.startTime?.hour}:${match.startTime?.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPracticesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practices (${_practices.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _practices.isEmpty
              ? const Center(child: Text('No practices yet. Tap + to add one!'))
              : ListView.builder(
                  itemCount: _practices.length,
                  itemBuilder: (context, index) {
                    final practice = _practices[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.fitness_center,
                          color: Color(0xFF00FF88),
                        ),
                        title: Text(practice.practiceTitle),
                        subtitle: Text(DateFormatter.formatDate(practice.date)),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  PracticeCollectionPage(practice: practice),
                            ),
                          );
                        },
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreatePlayerModal(BuildContext context) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final jerseyNumberController = TextEditingController();
    Team? selectedTeam;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Player'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: jerseyNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Jersey Number (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Team>(
                      value: selectedTeam,
                      decoration: const InputDecoration(
                        labelText: 'Team (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: _teams.map((Team team) {
                        return DropdownMenuItem<Team>(
                          value: team,
                          child: Text(team.teamName),
                        );
                      }).toList(),
                      onChanged: (Team? newValue) {
                        setState(() {
                          selectedTeam = newValue;
                        });
                      },
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
                  onPressed: () async {
                    if (firstNameController.text.isNotEmpty &&
                        lastNameController.text.isNotEmpty) {
                      final jerseyNumber =
                          jerseyNumberController.text.isNotEmpty
                          ? int.parse(jerseyNumberController.text)
                          : null;
                      final player = Player(
                        firstName: firstNameController.text,
                        lastName: lastNameController.text,
                        jerseyNumber: jerseyNumber,
                        teamId: selectedTeam?.id,
                      );
                      await _dbHelper.insertPlayer(player);
                      _loadData();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateTeamModal(BuildContext context) {
    final teamNameController = TextEditingController();
    final clubNameController = TextEditingController();
    final ageController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Team'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: teamNameController,
                  decoration: const InputDecoration(
                    labelText: 'Team Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: clubNameController,
                  decoration: const InputDecoration(
                    labelText: 'Club Name',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age Group',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
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
              onPressed: () async {
                if (teamNameController.text.isNotEmpty &&
                    clubNameController.text.isNotEmpty &&
                    ageController.text.isNotEmpty) {
                  final team = Team(
                    teamName: teamNameController.text,
                    clubName: clubNameController.text,
                    age: int.parse(ageController.text),
                  );
                  await _dbHelper.insertTeam(team);
                  _loadData();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateMatchModal(BuildContext context) {
    Team? selectedHomeTeam;
    Team? selectedAwayTeam;
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Match'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Team>(
                      value: selectedHomeTeam,
                      decoration: const InputDecoration(
                        labelText: 'Home Team',
                        border: OutlineInputBorder(),
                      ),
                      items: _teams.map((Team team) {
                        return DropdownMenuItem<Team>(
                          value: team,
                          child: Text(team.teamName),
                        );
                      }).toList(),
                      onChanged: (Team? newValue) {
                        setState(() {
                          selectedHomeTeam = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Team>(
                      value: selectedAwayTeam,
                      decoration: const InputDecoration(
                        labelText: 'Away Team',
                        border: OutlineInputBorder(),
                      ),
                      items: _teams.map((Team team) {
                        return DropdownMenuItem<Team>(
                          value: team,
                          child: Text(team.teamName),
                        );
                      }).toList(),
                      onChanged: (Team? newValue) {
                        setState(() {
                          selectedAwayTeam = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('Date'),
                            subtitle: Text(
                              DateFormatter.formatDate(selectedDate),
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() {
                                  selectedDate = date;
                                });
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('Time'),
                            subtitle: Text(selectedTime.format(context)),
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (time != null) {
                                setState(() {
                                  selectedTime = time;
                                });
                              }
                            },
                          ),
                        ),
                      ],
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
                  onPressed: () async {
                    if (selectedHomeTeam != null && selectedAwayTeam != null) {
                      final startTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      final match = Match(
                        homeTeam: selectedHomeTeam!,
                        awayTeam: selectedAwayTeam!,
                        startTime: startTime,
                      );
                      await _dbHelper.insertMatch(match);
                      _loadData();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResetDatabaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Database'),
          content: const Text(
            'This will delete all players, teams, and matches. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _dbHelper.resetDatabase();
                _loadData();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showCreatePracticeModal(BuildContext context) {
    Team? selectedTeam;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create New Practice'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Team>(
                      value: selectedTeam,
                      decoration: const InputDecoration(
                        labelText: 'Team',
                        border: OutlineInputBorder(),
                      ),
                      items: _teams.map((Team team) {
                        return DropdownMenuItem<Team>(
                          value: team,
                          child: Text(team.teamName),
                        );
                      }).toList(),
                      onChanged: (Team? newValue) {
                        setState(() {
                          selectedTeam = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Practice Date'),
                      subtitle: Text(DateFormatter.formatDate(selectedDate)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
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
                  onPressed: () async {
                    if (selectedTeam != null) {
                      final practice = Practice(
                        team: selectedTeam!,
                        date: selectedDate,
                      );
                      final practiceId = await _dbHelper.insertPractice(
                        practice,
                      );

                      // Add all team players to the practice
                      final teamPlayers = _players
                          .where((player) => player.teamId == selectedTeam!.id)
                          .toList();

                      print(
                        'Found ${teamPlayers.length} players for team ${selectedTeam!.teamName}',
                      );

                      for (final player in teamPlayers) {
                        print(
                          'Adding player ${player.fullName} to practice $practiceId',
                        );
                        await _dbHelper.addPlayerToPractice(
                          practiceId,
                          player.id!,
                        );
                      }

                      print('Finished adding players to practice');

                      _loadData();
                      Navigator.of(context).pop();

                      // Navigate to practice stats page
                      final createdPractice = Practice(
                        id: practiceId,
                        team: selectedTeam!,
                        date: selectedDate,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              PracticeCollectionPage(practice: createdPractice),
                        ),
                      );
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditPlayerModal(BuildContext context, Player player) {
    final firstNameController = TextEditingController(text: player.firstName);
    final lastNameController = TextEditingController(text: player.lastName);
    final jerseyNumberController = TextEditingController(
      text: player.jerseyNumber?.toString() ?? '',
    );
    Team? selectedTeam = _teams.firstWhere(
      (team) => team.id == player.teamId,
      orElse: () => _teams.first,
    );
    if (player.teamId == null) selectedTeam = null;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Player'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: jerseyNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Jersey Number (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Team>(
                      value: selectedTeam,
                      decoration: const InputDecoration(
                        labelText: 'Team (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<Team>(
                          value: null,
                          child: Text('No Team'),
                        ),
                        ..._teams.map((Team team) {
                          return DropdownMenuItem<Team>(
                            value: team,
                            child: Text(team.teamName),
                          );
                        }).toList(),
                      ],
                      onChanged: (Team? newValue) {
                        setState(() {
                          selectedTeam = newValue;
                        });
                      },
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
                  onPressed: () async {
                    if (firstNameController.text.isNotEmpty &&
                        lastNameController.text.isNotEmpty) {
                      final jerseyNumber =
                          jerseyNumberController.text.isNotEmpty
                          ? int.parse(jerseyNumberController.text)
                          : null;
                      final updatedPlayer = Player(
                        id: player.id,
                        firstName: firstNameController.text,
                        lastName: lastNameController.text,
                        jerseyNumber: jerseyNumber,
                        teamId: selectedTeam?.id,
                      );
                      await _dbHelper.updatePlayer(updatedPlayer);
                      _loadData();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTeamModal(BuildContext context, Team team) async {
    final teamNameController = TextEditingController(text: team.teamName);
    final clubNameController = TextEditingController(text: team.clubName);
    final ageController = TextEditingController(text: team.age.toString());

    // Load current team players
    final allPlayers = await _dbHelper.getAllPlayers();
    final currentTeamPlayers = allPlayers
        .where((player) => player.teamId == team.id)
        .toList();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Team'),
              content: SizedBox(
                width: double.maxFinite,
                height: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Team Details Section
                      const Text(
                        'Team Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: teamNameController,
                        decoration: const InputDecoration(
                          labelText: 'Team Name',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: clubNameController,
                        decoration: const InputDecoration(
                          labelText: 'Club Name',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: ageController,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),

                      // Current Players Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Players',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showAddPlayerToTeamModal(
                              context,
                              team,
                              setState,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Player'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Current Players List
                      if (currentTeamPlayers.isEmpty)
                        const Text(
                          'No players on this team',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        ...currentTeamPlayers
                            .map(
                              (player) => Card(
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.person,
                                    color: Color(0xFF00E5FF),
                                  ),
                                  title: Text(player.fullName),
                                  subtitle: Text(player.jerseyDisplay),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      // Remove player from team by setting teamId to null
                                      final updatedPlayer = Player(
                                        id: player.id,
                                        firstName: player.firstName,
                                        lastName: player.lastName,
                                        jerseyNumber: player.jerseyNumber,
                                        teamId: null,
                                      );
                                      await _dbHelper.updatePlayer(
                                        updatedPlayer,
                                      );
                                      _loadData(); // Refresh main data
                                      setState(() {}); // Refresh modal state
                                    },
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (teamNameController.text.isNotEmpty &&
                        clubNameController.text.isNotEmpty &&
                        ageController.text.isNotEmpty) {
                      final updatedTeam = Team(
                        id: team.id,
                        teamName: teamNameController.text,
                        clubName: clubNameController.text,
                        age: int.parse(ageController.text),
                      );
                      await _dbHelper.updateTeam(updatedTeam);
                      _loadData();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Update Team'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddPlayerToTeamModal(
    BuildContext context,
    Team team,
    StateSetter setState,
  ) async {
    final allPlayers = await _dbHelper.getAllPlayers();
    final availablePlayers = allPlayers
        .where((player) => player.teamId == null || player.teamId == team.id)
        .toList();
    final Set<int> selectedPlayerIds = <int>{};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return AlertDialog(
              title: const Text('Add Players to Team'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select players to add to ${team.teamName}:',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    if (availablePlayers.isEmpty)
                      const Text(
                        'No available players to add',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: availablePlayers.length,
                          itemBuilder: (context, index) {
                            final player = availablePlayers[index];
                            final isSelected = selectedPlayerIds.contains(
                              player.id,
                            );
                            final isAlreadyOnTeam = player.teamId == team.id;

                            return Card(
                              child: CheckboxListTile(
                                title: Text(player.fullName),
                                subtitle: Text(player.jerseyDisplay),
                                value: isSelected,
                                onChanged: isAlreadyOnTeam
                                    ? null
                                    : (bool? value) {
                                        modalSetState(() {
                                          if (value == true) {
                                            selectedPlayerIds.add(player.id!);
                                          } else {
                                            selectedPlayerIds.remove(player.id);
                                          }
                                        });
                                      },
                                secondary: isAlreadyOnTeam
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Color(0xFF00E5FF),
                                      ),
                                enabled: !isAlreadyOnTeam,
                              ),
                            );
                          },
                        ),
                      ),
                    if (selectedPlayerIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${selectedPlayerIds.length} player(s) selected',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF),
                          ),
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
                  onPressed: selectedPlayerIds.isEmpty
                      ? null
                      : () async {
                          // Add all selected players to the team
                          for (final playerId in selectedPlayerIds) {
                            final player = availablePlayers.firstWhere(
                              (p) => p.id == playerId,
                            );
                            final updatedPlayer = Player(
                              id: player.id,
                              firstName: player.firstName,
                              lastName: player.lastName,
                              jerseyNumber: player.jerseyNumber,
                              teamId: team.id,
                            );
                            await _dbHelper.updatePlayer(updatedPlayer);
                          }
                          _loadData(); // Refresh main data
                          setState(() {}); // Refresh modal state
                          Navigator.of(context).pop();
                        },
                  child: Text(
                    selectedPlayerIds.isEmpty
                        ? 'Add Players'
                        : 'Add ${selectedPlayerIds.length} Player(s)',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
