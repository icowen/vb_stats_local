import '../database_helper.dart';
import '../models/player.dart';

class PlayerService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Player CRUD operations
  Future<int> insertPlayer(Player player) async {
    final db = await _dbHelper.database;
    return await db.insert('players', player.toMap());
  }

  Future<List<Player>> getAllPlayers() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('players');
    return List.generate(maps.length, (i) => Player.fromMap(maps[i]));
  }

  Future<Player?> getPlayer(int id) async {
    final db = await _dbHelper.database;
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
    final db = await _dbHelper.database;
    return await db.update(
      'players',
      player.toMap(),
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  Future<int> deletePlayer(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('players', where: 'id = ?', whereArgs: [id]);
  }

  // Team-Player relationship operations
  Future<void> addPlayerToTeam(int teamId, int playerId) async {
    final db = await _dbHelper.database;
    await db.insert('team_players', {'teamId': teamId, 'playerId': playerId});
  }

  Future<void> removePlayerFromTeam(int teamId, int playerId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'team_players',
      where: 'teamId = ? AND playerId = ?',
      whereArgs: [teamId, playerId],
    );
  }

  Future<List<Player>> getTeamPlayers(int teamId) async {
    final db = await _dbHelper.database;
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
    final db = await _dbHelper.database;
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
    final db = await _dbHelper.database;
    await db.delete(
      'practice_players',
      where: 'practiceId = ? AND playerId = ?',
      whereArgs: [practiceId, playerId],
    );
  }

  Future<bool> isPlayerInPractice(int practiceId, int playerId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'practice_players',
      where: 'practiceId = ? AND playerId = ?',
      whereArgs: [practiceId, playerId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<List<Player>> getPracticePlayers(int practiceId) async {
    final db = await _dbHelper.database;
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
}
