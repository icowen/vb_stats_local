import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/player.dart';
import 'models/team.dart';
import 'models/match.dart';
import 'models/practice.dart';
import 'models/event.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'vb_stats.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Check and create tables if they don't exist
  Future<void> ensureTablesExist() async {
    final db = await database;

    // List of all required tables with their CREATE statements
    final tables = [
      {
        'name': 'players',
        'create': '''
          CREATE TABLE IF NOT EXISTS players(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            firstName TEXT NOT NULL,
            lastName TEXT NOT NULL,
            jerseyNumber INTEGER,
            teamId INTEGER,
            FOREIGN KEY (teamId) REFERENCES teams (id) ON DELETE SET NULL
          )
        ''',
      },
      {
        'name': 'teams',
        'create': '''
          CREATE TABLE IF NOT EXISTS teams(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teamName TEXT NOT NULL,
            clubName TEXT NOT NULL,
            age INTEGER NOT NULL
          )
        ''',
      },
      {
        'name': 'team_players',
        'create': '''
          CREATE TABLE IF NOT EXISTS team_players(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teamId INTEGER,
            playerId INTEGER,
            FOREIGN KEY (teamId) REFERENCES teams (id) ON DELETE CASCADE,
            FOREIGN KEY (playerId) REFERENCES players (id) ON DELETE CASCADE
          )
        ''',
      },
      {
        'name': 'matches',
        'create': '''
          CREATE TABLE IF NOT EXISTS matches(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            homeTeamId INTEGER,
            awayTeamId INTEGER,
            startTime INTEGER,
            FOREIGN KEY (homeTeamId) REFERENCES teams (id) ON DELETE CASCADE,
            FOREIGN KEY (awayTeamId) REFERENCES teams (id) ON DELETE CASCADE
          )
        ''',
      },
      {
        'name': 'practices',
        'create': '''
          CREATE TABLE IF NOT EXISTS practices(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            teamId INTEGER,
            date INTEGER,
            FOREIGN KEY (teamId) REFERENCES teams (id) ON DELETE CASCADE
          )
        ''',
      },
      {
        'name': 'practice_players',
        'create': '''
          CREATE TABLE IF NOT EXISTS practice_players(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            practiceId INTEGER,
            playerId INTEGER,
            FOREIGN KEY (practiceId) REFERENCES practices (id) ON DELETE CASCADE,
            FOREIGN KEY (playerId) REFERENCES players (id) ON DELETE CASCADE
          )
        ''',
      },
      {
        'name': 'events',
        'create': '''
          CREATE TABLE IF NOT EXISTS events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            practiceId INTEGER,
            matchId INTEGER,
            playerId INTEGER,
            teamId INTEGER,
            type TEXT NOT NULL,
            metadata TEXT,
            timestamp INTEGER NOT NULL,
            FOREIGN KEY (practiceId) REFERENCES practices (id) ON DELETE CASCADE,
            FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE,
            FOREIGN KEY (playerId) REFERENCES players (id) ON DELETE CASCADE,
            FOREIGN KEY (teamId) REFERENCES teams (id) ON DELETE CASCADE
          )
        ''',
      },
    ];

    // Check each table and create if it doesn't exist
    for (final table in tables) {
      try {
        // Try to query the table to see if it exists
        final result = await db.rawQuery(
          'SELECT name FROM sqlite_master WHERE type="table" AND name="${table['name']}"',
        );

        // If the query returns empty, the table doesn't exist
        if (result.isEmpty) {
          print('Creating missing table: ${table['name']}');
          await db.execute(table['create']!);
        }
      } catch (e) {
        // If there's an error checking, try to create the table
        print(
          'Error checking table ${table['name']}, attempting to create: $e',
        );
        try {
          await db.execute(table['create']!);
          print('Successfully created table: ${table['name']}');
        } catch (createError) {
          print('Failed to create table ${table['name']}: $createError');
        }
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create players table
    await db.execute('''
      CREATE TABLE players(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT,
        lastName TEXT,
        jerseyNumber INTEGER
      )
    ''');

    // Create teams table
    await db.execute('''
      CREATE TABLE teams(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teamName TEXT,
        clubName TEXT,
        age INTEGER
      )
    ''');

    // Create team_players junction table
    await db.execute('''
      CREATE TABLE team_players(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teamId INTEGER,
        playerId INTEGER,
        FOREIGN KEY (teamId) REFERENCES teams (id) ON DELETE CASCADE,
        FOREIGN KEY (playerId) REFERENCES players (id) ON DELETE CASCADE,
        UNIQUE(teamId, playerId)
      )
    ''');

    // Create matches table
    await db.execute('''
      CREATE TABLE matches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        homeTeamId INTEGER,
        awayTeamId INTEGER,
        startTime INTEGER,
        FOREIGN KEY (homeTeamId) REFERENCES teams (id) ON DELETE CASCADE,
        FOREIGN KEY (awayTeamId) REFERENCES teams (id) ON DELETE CASCADE
      )
    ''');

    // Create practices table
    await db.execute('''
      CREATE TABLE practices(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teamId INTEGER,
        date INTEGER,
        FOREIGN KEY (teamId) REFERENCES teams (id) ON DELETE CASCADE
      )
    ''');

    // Create practice_players junction table
    await db.execute('''
      CREATE TABLE practice_players(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        practiceId INTEGER,
        playerId INTEGER,
        FOREIGN KEY (practiceId) REFERENCES practices (id) ON DELETE CASCADE,
        FOREIGN KEY (playerId) REFERENCES players (id) ON DELETE CASCADE,
        UNIQUE(practiceId, playerId)
      )
    ''');

    // Create events table
    await db.execute('''
      CREATE TABLE events(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        practiceId INTEGER,
        matchId INTEGER,
        playerId INTEGER,
        teamId INTEGER,
        type TEXT NOT NULL,
        metadata TEXT,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (practiceId) REFERENCES practices (id) ON DELETE CASCADE,
        FOREIGN KEY (matchId) REFERENCES matches (id) ON DELETE CASCADE,
        FOREIGN KEY (playerId) REFERENCES players (id) ON DELETE CASCADE,
        FOREIGN KEY (teamId) REFERENCES teams (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add teamId column to players table
      await db.execute('ALTER TABLE players ADD COLUMN teamId INTEGER');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_players_teamId ON players(teamId)
      ''');
    }
  }

  // Player CRUD operations
  Future<int> insertPlayer(Player player) async {
    final db = await database;
    return await db.insert('players', player.toMap());
  }

  Future<List<Player>> getAllPlayers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('players');
    return List.generate(maps.length, (i) => Player.fromMap(maps[i]));
  }

  Future<Player?> getPlayer(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'players',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Player.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updatePlayer(Player player) async {
    final db = await database;
    return await db.update(
      'players',
      player.toMap(),
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  Future<int> deletePlayer(int id) async {
    final db = await database;
    return await db.delete('players', where: 'id = ?', whereArgs: [id]);
  }

  // Team CRUD operations
  Future<int> insertTeam(Team team) async {
    final db = await database;
    return await db.insert('teams', team.toMap());
  }

  Future<List<Team>> getAllTeams() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('teams');
    return List.generate(maps.length, (i) => Team.fromMap(maps[i]));
  }

  Future<Team?> getTeam(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'teams',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Team.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateTeam(Team team) async {
    final db = await database;
    return await db.update(
      'teams',
      team.toMap(),
      where: 'id = ?',
      whereArgs: [team.id],
    );
  }

  Future<int> deleteTeam(int id) async {
    final db = await database;
    return await db.delete('teams', where: 'id = ?', whereArgs: [id]);
  }

  // Team-Player relationship operations
  Future<void> addPlayerToTeam(int teamId, int playerId) async {
    final db = await database;
    await db.insert('team_players', {'teamId': teamId, 'playerId': playerId});
  }

  Future<void> removePlayerFromTeam(int teamId, int playerId) async {
    final db = await database;
    await db.delete(
      'team_players',
      where: 'teamId = ? AND playerId = ?',
      whereArgs: [teamId, playerId],
    );
  }

  Future<List<Player>> getTeamPlayers(int teamId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM players
      WHERE teamId = ?
    ''',
      [teamId],
    );
    return List.generate(maps.length, (i) => Player.fromMap(maps[i]));
  }

  // Practice-Player relationship operations
  Future<void> addPlayerToPractice(int practiceId, int playerId) async {
    final db = await database;
    try {
      await db.insert('practice_players', {
        'practiceId': practiceId,
        'playerId': playerId,
      });
    } catch (e) {
      // Handle unique constraint violation (duplicate entry)
      if (e.toString().contains('UNIQUE constraint failed')) {
        print('Player $playerId is already in practice $practiceId');
        return; // Silently ignore duplicate entries
      }
      rethrow; // Re-throw other errors
    }
  }

  Future<void> removePlayerFromPractice(int practiceId, int playerId) async {
    final db = await database;
    await db.delete(
      'practice_players',
      where: 'practiceId = ? AND playerId = ?',
      whereArgs: [practiceId, playerId],
    );
  }

  Future<bool> isPlayerInPractice(int practiceId, int playerId) async {
    final db = await database;
    final result = await db.query(
      'practice_players',
      where: 'practiceId = ? AND playerId = ?',
      whereArgs: [practiceId, playerId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Player>> getPracticePlayers(int practiceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT p.* FROM players p
      INNER JOIN practice_players pp ON p.id = pp.playerId
      WHERE pp.practiceId = ?
    ''',
      [practiceId],
    );
    return List.generate(maps.length, (i) => Player.fromMap(maps[i]));
  }

  // Match CRUD operations
  Future<int> insertMatch(Match match) async {
    final db = await database;
    return await db.insert('matches', match.toMap());
  }

  Future<List<Match>> getAllMatches() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('matches');
    List<Match> matches = [];
    for (var map in maps) {
      final homeTeam = await getTeam(map['homeTeamId']);
      final awayTeam = await getTeam(map['awayTeamId']);
      if (homeTeam != null && awayTeam != null) {
        matches.add(Match.fromMap(map, homeTeam: homeTeam, awayTeam: awayTeam));
      }
    }
    return matches;
  }

  Future<Match?> getMatch(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'matches',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      final homeTeam = await getTeam(map['homeTeamId']);
      final awayTeam = await getTeam(map['awayTeamId']);
      if (homeTeam != null && awayTeam != null) {
        return Match.fromMap(map, homeTeam: homeTeam, awayTeam: awayTeam);
      }
    }
    return null;
  }

  Future<int> updateMatch(Match match) async {
    final db = await database;
    return await db.update(
      'matches',
      match.toMap(),
      where: 'id = ?',
      whereArgs: [match.id],
    );
  }

  Future<int> deleteMatch(int id) async {
    final db = await database;
    return await db.delete('matches', where: 'id = ?', whereArgs: [id]);
  }

  // Practice CRUD operations
  Future<int> insertPractice(Practice practice) async {
    final db = await database;
    return await db.insert('practices', practice.toMap());
  }

  Future<List<Practice>> getAllPractices() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('practices');
    List<Practice> practices = [];
    for (var map in maps) {
      final team = await getTeam(map['teamId']);
      if (team != null) {
        practices.add(Practice.fromMap(map, team: team));
      }
    }
    return practices;
  }

  Future<Practice?> getPractice(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'practices',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      final team = await getTeam(map['teamId']);
      if (team != null) {
        return Practice.fromMap(map, team: team);
      }
    }
    return null;
  }

  Future<int> updatePractice(Practice practice) async {
    final db = await database;
    return await db.update(
      'practices',
      practice.toMap(),
      where: 'id = ?',
      whereArgs: [practice.id],
    );
  }

  Future<int> deletePractice(int id) async {
    final db = await database;
    return await db.delete('practices', where: 'id = ?', whereArgs: [id]);
  }

  // Event CRUD operations
  Future<int> insertEvent(Event event) async {
    final db = await database;
    return await db.insert('events', event.toMap());
  }

  Future<List<Event>> getAllEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('events');
    List<Event> events = [];
    for (var map in maps) {
      final player = await getPlayer(map['playerId']);
      final team = await getTeam(map['teamId']);
      Practice? practice;
      Match? match;

      if (map['practiceId'] != null) {
        practice = await getPractice(map['practiceId']);
      }
      if (map['matchId'] != null) {
        match = await getMatch(map['matchId']);
      }

      if (player != null && team != null) {
        events.add(
          Event.fromMap(
            map,
            player: player,
            team: team,
            practice: practice,
            match: match,
          ),
        );
      }
    }
    return events;
  }

  Future<List<Event>> getEventsForPractice(int practiceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'practiceId = ?',
      whereArgs: [practiceId],
    );
    List<Event> events = [];
    for (var map in maps) {
      final player = await getPlayer(map['playerId']);
      final team = await getTeam(map['teamId']);
      final practice = await getPractice(practiceId);

      if (player != null && team != null && practice != null) {
        events.add(
          Event.fromMap(map, player: player, team: team, practice: practice),
        );
      }
    }
    return events;
  }

  Future<List<Event>> getEventsForMatch(int matchId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
    List<Event> events = [];
    for (var map in maps) {
      final player = await getPlayer(map['playerId']);
      final team = await getTeam(map['teamId']);
      final match = await getMatch(matchId);

      if (player != null && team != null && match != null) {
        events.add(
          Event.fromMap(map, player: player, team: team, match: match),
        );
      }
    }
    return events;
  }

  Future<List<Event>> getEventsForPlayer(int playerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'playerId = ?',
      whereArgs: [playerId],
    );
    List<Event> events = [];
    for (var map in maps) {
      final player = await getPlayer(playerId);
      final team = await getTeam(map['teamId']);
      Practice? practice;
      Match? match;

      if (map['practiceId'] != null) {
        practice = await getPractice(map['practiceId']);
      }
      if (map['matchId'] != null) {
        match = await getMatch(map['matchId']);
      }

      if (player != null && team != null) {
        events.add(
          Event.fromMap(
            map,
            player: player,
            team: team,
            practice: practice,
            match: match,
          ),
        );
      }
    }
    return events;
  }

  Future<Event?> getEvent(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      final player = await getPlayer(map['playerId']);
      final team = await getTeam(map['teamId']);
      Practice? practice;
      Match? match;

      if (map['practiceId'] != null) {
        practice = await getPractice(map['practiceId']);
      }
      if (map['matchId'] != null) {
        match = await getMatch(map['matchId']);
      }

      if (player != null && team != null) {
        return Event.fromMap(
          map,
          player: player,
          team: team,
          practice: practice,
          match: match,
        );
      }
    }
    return null;
  }

  Future<int> updateEvent(Event event) async {
    final db = await database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(int id) async {
    final db = await database;
    return await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // Clear all data from database
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('events');
    await db.delete('practice_players');
    await db.delete('practices');
    await db.delete('matches');
    await db.delete('team_players');
    await db.delete('teams');
    await db.delete('players');
  }

  // Drop and recreate database
  Future<void> resetDatabase() async {
    final db = await database;
    await db.close();
    _database = null;

    // Delete the database file
    String path = join(await getDatabasesPath(), 'counter.db');
    await deleteDatabase(path);

    // Reinitialize
    _database = await _initDatabase();
  }
}
