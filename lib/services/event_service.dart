import '../database_helper.dart';
import '../models/event.dart';
import '../models/match.dart';
import '../models/practice.dart';
import 'player_service.dart';
import 'team_service.dart';
import 'practice_service.dart';
import 'match_service.dart';

class EventService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final PlayerService _playerService = PlayerService();
  final TeamService _teamService = TeamService();
  final PracticeService _practiceService = PracticeService();
  final MatchService _matchService = MatchService();

  // Event CRUD operations
  Future<int> insertEvent(Event event) async {
    final db = await _dbHelper.database;
    return await db.insert('events', event.toMap());
  }

  Future<List<Event>> getAllEvents() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('events');
    List<Event> events = [];
    for (var map in maps) {
      final player = await _playerService.getPlayer(map['playerId']);
      final team = await _teamService.getTeam(map['teamId']);
      Practice? practice;
      Match? match;

      if (map['practiceId'] != null) {
        practice = await _practiceService.getPractice(map['practiceId']);
      }
      if (map['matchId'] != null) {
        match = await _matchService.getMatch(map['matchId']);
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
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'practiceId = ?',
      whereArgs: [practiceId],
    );
    List<Event> events = [];
    for (var map in maps) {
      final player = await _playerService.getPlayer(map['playerId']);
      final team = await _teamService.getTeam(map['teamId']);
      final practice = await _practiceService.getPractice(practiceId);

      if (player != null && team != null && practice != null) {
        events.add(
          Event.fromMap(map, player: player, team: team, practice: practice),
        );
      }
    }
    return events;
  }

  Future<List<Event>> getEventsForMatch(int matchId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'matchId = ?',
      whereArgs: [matchId],
    );
    List<Event> events = [];
    for (var map in maps) {
      final player = await _playerService.getPlayer(map['playerId']);
      final team = await _teamService.getTeam(map['teamId']);
      final match = await _matchService.getMatch(matchId);

      if (player != null && team != null && match != null) {
        events.add(
          Event.fromMap(map, player: player, team: team, match: match),
        );
      }
    }
    return events;
  }

  Future<List<Event>> getEventsForPlayer(int playerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'playerId = ?',
      whereArgs: [playerId],
    );
    List<Event> events = [];
    for (var map in maps) {
      final player = await _playerService.getPlayer(playerId);
      final team = await _teamService.getTeam(map['teamId']);
      Practice? practice;
      Match? match;

      if (map['practiceId'] != null) {
        practice = await _practiceService.getPractice(map['practiceId']);
      }
      if (map['matchId'] != null) {
        match = await _matchService.getMatch(map['matchId']);
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
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final map = maps.first;
      final player = await _playerService.getPlayer(map['playerId']);
      final team = await _teamService.getTeam(map['teamId']);
      Practice? practice;
      Match? match;

      if (map['practiceId'] != null) {
        practice = await _practiceService.getPractice(map['practiceId']);
      }
      if (map['matchId'] != null) {
        match = await _matchService.getMatch(map['matchId']);
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
    final db = await _dbHelper.database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }
}
