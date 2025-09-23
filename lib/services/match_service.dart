import '../database_helper.dart';
import '../models/match.dart';
import 'team_service.dart';

class MatchService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TeamService _teamService = TeamService();

  // Match CRUD operations
  Future<int> insertMatch(Match match) async {
    final db = await _dbHelper.database;
    return await db.insert('matches', match.toMap());
  }

  Future<List<Match>> getAllMatches() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('matches');
    List<Match> matches = [];
    for (var map in maps) {
      final homeTeam = await _teamService.getTeam(map['homeTeamId']);
      final awayTeam = await _teamService.getTeam(map['awayTeamId']);
      if (homeTeam != null && awayTeam != null) {
        matches.add(Match.fromMap(map, homeTeam: homeTeam, awayTeam: awayTeam));
      }
    }
    return matches;
  }

  Future<Match?> getMatch(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'matches',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      final homeTeam = await _teamService.getTeam(map['homeTeamId']);
      final awayTeam = await _teamService.getTeam(map['awayTeamId']);
      if (homeTeam != null && awayTeam != null) {
        return Match.fromMap(map, homeTeam: homeTeam, awayTeam: awayTeam);
      }
    }
    return null;
  }

  Future<int> updateMatch(Match match) async {
    final db = await _dbHelper.database;
    return await db.update(
      'matches',
      match.toMap(),
      where: 'id = ?',
      whereArgs: [match.id],
    );
  }

  Future<int> deleteMatch(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('matches', where: 'id = ?', whereArgs: [id]);
  }
}
