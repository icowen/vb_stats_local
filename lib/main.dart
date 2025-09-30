import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database_helper.dart';
import 'services/player_service.dart';
import 'services/team_service.dart';
import 'services/match_service.dart';
import 'services/practice_service.dart';
import 'models/player.dart';
import 'models/team.dart';
import 'models/match.dart';
import 'models/practice.dart';
import 'pages/practice_stats_page.dart';
import 'utils/date_utils.dart';
import 'utils/app_colors.dart';
import 'providers/practice_stats_provider.dart';
import 'providers/player_selection_provider.dart';
import 'providers/event_provider.dart';
import 'providers/settings_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PracticeStatsProvider()),
        ChangeNotifierProvider(create: (_) => PlayerSelectionProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
            onPrimary: Colors.black,
            onSecondary: Colors.black,
            onSurface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.appBarBackground,
            foregroundColor: Colors.white,
          ),
          cardTheme: const CardThemeData(
            color: AppColors.appBarBackground,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            labelStyle: TextStyle(color: AppColors.primary),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            menuStyle: MenuStyle(
              backgroundColor: WidgetStateProperty.all(
                AppColors.appBarBackground,
              ),
            ),
          ),
        ),
        home: const MyHomePage(title: 'Volleyball Stats'),
      ),
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
  final PlayerService _playerService = PlayerService();
  final TeamService _teamService = TeamService();
  final MatchService _matchService = MatchService();
  final PracticeService _practiceService = PracticeService();
  List<Player> _players = [];
  List<Team> _teams = [];
  List<Match> _matches = [];
  List<Practice> _practices = [];
  bool _isLoading = true;
  String? _expandedTile = 'practices';

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.initialize();
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

      final players = await _playerService.getAllPlayers();
      final teams = await _teamService.getAllTeams();
      final matches = await _matchService.getAllMatches();
      final practices = await _practiceService.getAllPractices();

      // Sort practices by date (newest to oldest)
      practices.sort((a, b) => b.date.compareTo(a.date));

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
            onPressed: () => _showSettingsModal(context),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: () => _showResetDatabaseDialog(context),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Database',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
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
                            AppColors.primary,
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
                            AppColors.secondary,
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
                            AppColors.primary,
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
                            AppColors.secondary,
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
    final isSelected = _expandedTile == title.toLowerCase();
    return Card(
      color: isSelected ? color.withValues(alpha: 0.1) : null,
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
                    color: color.withValues(alpha: 0.1),
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
    switch (_expandedTile) {
      case 'players':
        return _buildPlayersList();
      case 'teams':
        return _buildTeamsList();
      case 'matches':
        return _buildMatchesList();
      case 'practices':
      default:
        return _buildPracticesList();
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
                          color: AppColors.primary,
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
                          color: AppColors.secondary,
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
                          color: AppColors.primary,
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
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  PracticeCollectionPage(practice: practice),
                            ),
                          );
                        },
                        onLongPress: () =>
                            _showPracticeOptions(context, practice),
                        child: ListTile(
                          leading: const Icon(
                            Icons.fitness_center,
                            color: AppColors.secondary,
                          ),
                          title: Text(practice.practiceTitle),
                          subtitle: Text(
                            DateFormatter.formatDate(practice.date),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showPracticeOptions(BuildContext context, Practice practice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.courtBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                practice.practiceTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormatter.formatDate(practice.date),
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _editPractice(context, practice);
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: const Text(
                        'Edit',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _deletePractice(context, practice);
                      },
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.redError,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _editPractice(BuildContext context, Practice practice) {
    DateTime selectedDate = practice.date;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.courtBackground,
              title: const Text(
                'Edit Practice',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[600]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Practice: ${practice.practiceTitle}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select new date:',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                                surface: Color(0xFF2D2D2D),
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (date != null) {
                        setState(() {
                          selectedDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormatter.formatDate(selectedDate),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    // Store reference to the main widget's context
                    final mainContext = this.context;

                    try {
                      final updatedPractice = Practice(
                        id: practice.id,
                        date: selectedDate,
                        team: practice.team,
                      );

                      await _practiceService.updatePractice(updatedPractice);
                      await _loadData();

                      if (mainContext.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(mainContext).showSnackBar(
                          const SnackBar(
                            content: Text('Practice date updated successfully'),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mainContext.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(mainContext).showSnackBar(
                          SnackBar(
                            content: Text('Error updating practice: $e'),
                            backgroundColor: AppColors.redError,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deletePractice(BuildContext context, Practice practice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.courtBackground,
          title: const Text(
            'Delete Practice',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${practice.practiceTitle}"?\n\nThis will also delete all actions recorded during this practice.',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                // Store reference to the main widget's context
                final mainContext = this.context;

                try {
                  await _practiceService.deletePractice(practice.id!);
                  await _loadData();

                  if (mainContext.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      const SnackBar(
                        content: Text('Practice deleted successfully'),
                        backgroundColor: AppColors.secondary,
                      ),
                    );
                  }
                } catch (e) {
                  if (mainContext.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(mainContext).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting practice: $e'),
                        backgroundColor: AppColors.redError,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: AppColors.redError),
              ),
            ),
          ],
        );
      },
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
                      initialValue: selectedTeam,
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
                      await _playerService.insertPlayer(player);
                      _loadData();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
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
                  await _teamService.insertTeam(team);
                  _loadData();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
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
                      initialValue: selectedHomeTeam,
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
                      initialValue: selectedAwayTeam,
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
                      await _matchService.insertMatch(match);
                      _loadData();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
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
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
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
                      initialValue: selectedTeam,
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
                      final practiceId = await _practiceService.insertPractice(
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
                        await _playerService.addPlayerToPractice(
                          practiceId,
                          player.id!,
                        );
                      }

                      print('Finished adding players to practice');

                      _loadData();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }

                      // Navigate to practice stats page
                      final createdPractice = Practice(
                        id: practiceId,
                        team: selectedTeam!,
                        date: selectedDate,
                      );
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PracticeCollectionPage(
                              practice: createdPractice,
                            ),
                          ),
                        );
                      }
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
                      initialValue: selectedTeam,
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
                      await _playerService.updatePlayer(updatedPlayer);
                      _loadData();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
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
    final allPlayers = await _playerService.getAllPlayers();
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
                                    color: AppColors.primary,
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
                                      await _playerService.updatePlayer(
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
                      await _teamService.updateTeam(updatedTeam);
                      _loadData();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
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
    final allPlayers = await _playerService.getAllPlayers();
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
                                        color: AppColors.primary,
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
                            color: AppColors.primary,
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
                            await _playerService.updatePlayer(updatedPlayer);
                          }
                          _loadData(); // Refresh main data
                          setState(() {}); // Refresh modal state
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
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
