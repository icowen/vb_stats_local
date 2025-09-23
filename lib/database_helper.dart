import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    String path = join(await getDatabasesPath(), 'vb_stats.db');
    await deleteDatabase(path);

    // Reinitialize
    _database = await _initDatabase();
  }
}
