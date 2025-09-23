import '../database_helper.dart';
import '../models/practice.dart';
import 'team_service.dart';

class PracticeService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TeamService _teamService = TeamService();

  // Practice CRUD operations
  Future<int> insertPractice(Practice practice) async {
    final db = await _dbHelper.database;
    return await db.insert('practices', practice.toMap());
  }

  Future<List<Practice>> getAllPractices() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('practices');
    List<Practice> practices = [];
    for (var map in maps) {
      final team = await _teamService.getTeam(map['teamId']);
      if (team != null) {
        practices.add(Practice.fromMap(map, team: team));
      }
    }
    return practices;
  }

  Future<Practice?> getPractice(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'practices',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      final team = await _teamService.getTeam(map['teamId']);
      if (team != null) {
        return Practice.fromMap(map, team: team);
      }
    }
    return null;
  }

  Future<int> updatePractice(Practice practice) async {
    final db = await _dbHelper.database;
    return await db.update(
      'practices',
      practice.toMap(),
      where: 'id = ?',
      whereArgs: [practice.id],
    );
  }

  Future<int> deletePractice(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('practices', where: 'id = ?', whereArgs: [id]);
  }
}
