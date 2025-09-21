import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/player.dart';
import 'models/team.dart';
import 'models/match.dart';

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
    String path = join(await getDatabasesPath(), 'counter.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
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
      SELECT p.* FROM players p
      INNER JOIN team_players tp ON p.id = tp.playerId
      WHERE tp.teamId = ?
    ''',
      [teamId],
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

  // Clear all data from database
  Future<void> clearDatabase() async {
    final db = await database;
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
