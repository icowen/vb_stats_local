import '../database_helper.dart';
import '../models/team.dart';

class TeamService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Team CRUD operations
  Future<int> insertTeam(Team team) async {
    final db = await _dbHelper.database;
    return await db.insert('teams', team.toMap());
  }

  Future<List<Team>> getAllTeams() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('teams');
    return List.generate(maps.length, (i) => Team.fromMap(maps[i]));
  }

  Future<Team?> getTeam(int id) async {
    final db = await _dbHelper.database;
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
    final db = await _dbHelper.database;
    return await db.update(
      'teams',
      team.toMap(),
      where: 'id = ?',
      whereArgs: [team.id],
    );
  }

  Future<int> deleteTeam(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('teams', where: 'id = ?', whereArgs: [id]);
  }
}
