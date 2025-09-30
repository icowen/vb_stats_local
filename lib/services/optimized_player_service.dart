import '../models/player.dart';
import '../models/team.dart';
import 'optimized_database_service.dart';

/// Optimized player service using caching and batch operations
class OptimizedPlayerService {
  static final OptimizedPlayerService _instance =
      OptimizedPlayerService._internal();
  factory OptimizedPlayerService() => _instance;
  OptimizedPlayerService._internal();

  final OptimizedDatabaseService _dbService = OptimizedDatabaseService();

  /// Get a single player by ID
  Future<Player?> getPlayer(int id) async {
    return await _dbService.getPlayer(id);
  }

  /// Get all players
  Future<List<Player>> getAllPlayers() async {
    // This could be optimized further with caching
    final db = await _dbService.database;
    final maps = await db.query('players', orderBy: 'firstName, lastName');

    final players = <Player>[];
    for (final map in maps) {
      final player = Player.fromMap(map);
      players.add(player);
    }

    return players;
  }

  /// Get players by team ID
  Future<List<Player>> getPlayersByTeam(int teamId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'players',
      where: 'teamId = ?',
      whereArgs: [teamId],
      orderBy: 'firstName, lastName',
    );

    final players = <Player>[];
    for (final map in maps) {
      final player = Player.fromMap(map);
      players.add(player);
    }

    return players;
  }

  /// Get players for a practice (players assigned to a specific practice)
  Future<List<Player>> getPracticePlayers(int practiceId) async {
    final db = await _dbService.database;

    // This would require a practice_players junction table
    // For now, we'll return all players (this should be optimized)
    final maps = await db.query('players', orderBy: 'firstName, lastName');

    final players = <Player>[];
    for (final map in maps) {
      final player = Player.fromMap(map);
      players.add(player);
    }

    return players;
  }

  /// Batch get players by IDs
  Future<List<Player>> getPlayersByIds(List<int> ids) async {
    return await _dbService.getPlayersByIds(ids);
  }

  /// Insert a new player
  Future<int> insertPlayer(Player player) async {
    final db = await _dbService.database;

    try {
      final id = await db.insert('players', player.toMap());
      return id;
    } catch (e) {
      print('Error inserting player: $e');
      rethrow;
    }
  }

  /// Update a player
  Future<int> updatePlayer(Player player) async {
    final db = await _dbService.database;

    try {
      final result = await db.update(
        'players',
        player.toMap(),
        where: 'id = ?',
        whereArgs: [player.id],
      );

      return result;
    } catch (e) {
      print('Error updating player: $e');
      rethrow;
    }
  }

  /// Delete a player
  Future<int> deletePlayer(int id) async {
    final db = await _dbService.database;

    try {
      final result = await db.delete(
        'players',
        where: 'id = ?',
        whereArgs: [id],
      );

      return result;
    } catch (e) {
      print('Error deleting player: $e');
      rethrow;
    }
  }

  /// Batch insert players
  Future<void> batchInsertPlayers(List<Player> players) async {
    final db = await _dbService.database;

    try {
      await db.transaction((txn) async {
        for (final player in players) {
          await txn.insert('players', player.toMap());
        }
      });
    } catch (e) {
      print('Error batch inserting players: $e');
      rethrow;
    }
  }

  /// Search players by name
  Future<List<Player>> searchPlayers(String query) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'players',
      where: 'firstName LIKE ? OR lastName LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'firstName, lastName',
    );

    final players = <Player>[];
    for (final map in maps) {
      final player = Player.fromMap(map);
      players.add(player);
    }

    return players;
  }

  /// Get players by jersey number range
  Future<List<Player>> getPlayersByJerseyRange(
    int minJersey,
    int maxJersey,
  ) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'players',
      where: 'jerseyNumber >= ? AND jerseyNumber <= ?',
      whereArgs: [minJersey, maxJersey],
      orderBy: 'jerseyNumber',
    );

    final players = <Player>[];
    for (final map in maps) {
      final player = Player.fromMap(map);
      players.add(player);
    }

    return players;
  }

  /// Get team for a player
  Future<Team?> getTeamForPlayer(int playerId) async {
    final player = await getPlayer(playerId);
    if (player?.teamId == null) return null;

    return await _dbService.getTeam(player!.teamId!);
  }

  /// Get players with their teams (batch operation)
  Future<Map<Player, Team?>> getPlayersWithTeams(List<Player> players) async {
    final Map<Player, Team?> results = {};

    // Extract unique team IDs
    final teamIds = players
        .where((p) => p.teamId != null)
        .map((p) => p.teamId!)
        .toSet()
        .toList();

    // Batch load teams
    final teams = await _dbService.getTeamsByIds(teamIds);
    final teamMap = {for (final t in teams) t.id!: t};

    // Map players to their teams
    for (final player in players) {
      results[player] = player.teamId != null ? teamMap[player.teamId] : null;
    }

    return results;
  }

  /// Clear player caches
  void clearPlayerCaches() {
    _dbService.clearAllCaches();
  }
}
