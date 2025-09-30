import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/event.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/practice.dart';
import '../models/match.dart';

/// Optimized database service with caching, batch loading, and transactions
class OptimizedDatabaseService {
  static final OptimizedDatabaseService _instance =
      OptimizedDatabaseService._internal();
  factory OptimizedDatabaseService() => _instance;
  OptimizedDatabaseService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Public getter for database access
  Future<Database> get database => _dbHelper.database;

  // Cache for frequently accessed data
  final Map<int, Player> _playerCache = {};
  final Map<int, Team> _teamCache = {};
  final Map<int, Practice> _practiceCache = {};
  final Map<int, Match> _matchCache = {};
  final Map<String, List<Event>> _eventCache = {};

  // Cache timestamps for TTL (Time To Live)
  final Map<String, DateTime> _cacheTimestamps = {};

  // Cache TTL in seconds (5 minutes)
  static const int _cacheTTL = 300;

  /// Get player with caching
  Future<Player?> getPlayer(int id) async {
    // Check cache first
    if (_playerCache.containsKey(id) && _isCacheValid('player_$id')) {
      return _playerCache[id];
    }

    // Load from database
    final db = await _dbHelper.database;
    final maps = await db.query('players', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      final player = Player.fromMap(maps.first);
      _playerCache[id] = player;
      _cacheTimestamps['player_$id'] = DateTime.now();
      return player;
    }

    return null;
  }

  /// Get team with caching
  Future<Team?> getTeam(int id) async {
    // Check cache first
    if (_teamCache.containsKey(id) && _isCacheValid('team_$id')) {
      return _teamCache[id];
    }

    // Load from database
    final db = await _dbHelper.database;
    final maps = await db.query('teams', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      final team = Team.fromMap(maps.first);
      _teamCache[id] = team;
      _cacheTimestamps['team_$id'] = DateTime.now();
      return team;
    }

    return null;
  }

  /// Get practice with caching
  Future<Practice?> getPractice(int id) async {
    // Check cache first
    if (_practiceCache.containsKey(id) && _isCacheValid('practice_$id')) {
      return _practiceCache[id];
    }

    // Load from database
    final db = await _dbHelper.database;
    final maps = await db.query('practices', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      final practice = Practice.fromMap(maps.first);
      _practiceCache[id] = practice;
      _cacheTimestamps['practice_$id'] = DateTime.now();
      return practice;
    }

    return null;
  }

  /// Batch load players by IDs
  Future<List<Player>> getPlayersByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final List<Player> players = [];
    final List<int> uncachedIds = [];

    // Check cache first
    for (final id in ids) {
      if (_playerCache.containsKey(id) && _isCacheValid('player_$id')) {
        players.add(_playerCache[id]!);
      } else {
        uncachedIds.add(id);
      }
    }

    // Load uncached players from database
    if (uncachedIds.isNotEmpty) {
      final db = await _dbHelper.database;
      final placeholders = uncachedIds.map((_) => '?').join(',');
      final maps = await db.query(
        'players',
        where: 'id IN ($placeholders)',
        whereArgs: uncachedIds,
      );

      for (final map in maps) {
        final player = Player.fromMap(map);
        _playerCache[player.id!] = player;
        _cacheTimestamps['player_${player.id}'] = DateTime.now();
        players.add(player);
      }
    }

    return players;
  }

  /// Batch load teams by IDs
  Future<List<Team>> getTeamsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final List<Team> teams = [];
    final List<int> uncachedIds = [];

    // Check cache first
    for (final id in ids) {
      if (_teamCache.containsKey(id) && _isCacheValid('team_$id')) {
        teams.add(_teamCache[id]!);
      } else {
        uncachedIds.add(id);
      }
    }

    // Load uncached teams from database
    if (uncachedIds.isNotEmpty) {
      final db = await _dbHelper.database;
      final placeholders = uncachedIds.map((_) => '?').join(',');
      final maps = await db.query(
        'teams',
        where: 'id IN ($placeholders)',
        whereArgs: uncachedIds,
      );

      for (final map in maps) {
        final team = Team.fromMap(map);
        _teamCache[team.id!] = team;
        _cacheTimestamps['team_${team.id}'] = DateTime.now();
        teams.add(team);
      }
    }

    return teams;
  }

  /// Get events for practice with caching and batch loading
  Future<List<Event>> getEventsForPractice(int practiceId) async {
    final cacheKey = 'practice_events_$practiceId';

    // Check cache first
    if (_eventCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _eventCache[cacheKey]!;
    }

    // Load events from database
    final db = await _dbHelper.database;
    final eventMaps = await db.query(
      'events',
      where: 'practiceId = ?',
      whereArgs: [practiceId],
      orderBy: 'timestamp DESC',
    );

    if (eventMaps.isEmpty) {
      _eventCache[cacheKey] = [];
      _cacheTimestamps[cacheKey] = DateTime.now();
      return [];
    }

    // Extract unique IDs for batch loading
    final playerIds = eventMaps
        .map((e) => e['playerId'] as int)
        .toSet()
        .toList();
    final teamIds = eventMaps.map((e) => e['teamId'] as int).toSet().toList();

    // Batch load players and teams
    final players = await getPlayersByIds(playerIds);
    final teams = await getTeamsByIds(teamIds);

    // Create lookup maps
    final playerMap = {for (final p in players) p.id!: p};
    final teamMap = {for (final t in teams) t.id!: t};

    // Load practice
    final practice = await getPractice(practiceId);

    // Build events
    final events = <Event>[];
    for (final map in eventMaps) {
      final player = playerMap[map['playerId']];
      final team = teamMap[map['teamId']];

      if (player != null && team != null) {
        events.add(
          Event.fromMap(
            map,
            player: player,
            team: team,
            practice: practice,
            match: null,
          ),
        );
      }
    }

    // Cache results
    _eventCache[cacheKey] = events;
    _cacheTimestamps[cacheKey] = DateTime.now();

    return events;
  }

  /// Get events for player with caching
  Future<List<Event>> getEventsForPlayer(int playerId) async {
    final cacheKey = 'player_events_$playerId';

    // Check cache first
    if (_eventCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
      return _eventCache[cacheKey]!;
    }

    // Load events from database
    final db = await _dbHelper.database;
    final eventMaps = await db.query(
      'events',
      where: 'playerId = ?',
      whereArgs: [playerId],
      orderBy: 'timestamp DESC',
    );

    if (eventMaps.isEmpty) {
      _eventCache[cacheKey] = [];
      _cacheTimestamps[cacheKey] = DateTime.now();
      return [];
    }

    // Load player and team
    final player = await getPlayer(playerId);
    if (player == null) return [];

    final team = await getTeam(player.teamId!);
    if (team == null) return [];

    // Extract unique practice/match IDs
    final practiceIds = eventMaps
        .where((e) => e['practiceId'] != null)
        .map((e) => e['practiceId'] as int)
        .toSet()
        .toList();

    // Batch load practices
    final practices = <int, Practice>{};
    for (final id in practiceIds) {
      final practice = await getPractice(id);
      if (practice != null) {
        practices[id] = practice;
      }
    }

    // Build events
    final events = <Event>[];
    for (final map in eventMaps) {
      final practice = map['practiceId'] != null
          ? practices[map['practiceId'] as int]
          : null;

      events.add(
        Event.fromMap(
          map,
          player: player,
          team: team,
          practice: practice,
          match: null,
        ),
      );
    }

    // Cache results
    _eventCache[cacheKey] = events;
    _cacheTimestamps[cacheKey] = DateTime.now();

    return events;
  }

  /// Insert event with transaction support
  Future<int> insertEvent(Event event) async {
    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        await txn.insert('events', event.toMap());
      });

      // Invalidate related caches
      _invalidateEventCaches(event);

      return event.id ?? 0;
    } catch (e) {
      print('Error inserting event: $e');
      rethrow;
    }
  }

  /// Update event with transaction support
  Future<int> updateEvent(Event event) async {
    final db = await _dbHelper.database;

    try {
      final result = await db.transaction((txn) async {
        return await txn.update(
          'events',
          event.toMap(),
          where: 'id = ?',
          whereArgs: [event.id],
        );
      });

      // Invalidate related caches
      _invalidateEventCaches(event);

      return result;
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  /// Delete event with transaction support
  Future<int> deleteEvent(int eventId) async {
    final db = await _dbHelper.database;

    try {
      final result = await db.transaction((txn) async {
        return await txn.delete(
          'events',
          where: 'id = ?',
          whereArgs: [eventId],
        );
      });

      // Invalidate all event caches since we don't know which practice/player
      _invalidateAllEventCaches();

      return result;
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  /// Batch insert events
  Future<void> batchInsertEvents(List<Event> events) async {
    if (events.isEmpty) return;

    final db = await _dbHelper.database;

    try {
      await db.transaction((txn) async {
        for (final event in events) {
          await txn.insert('events', event.toMap());
        }
      });

      // Invalidate all event caches
      _invalidateAllEventCaches();
    } catch (e) {
      print('Error batch inserting events: $e');
      rethrow;
    }
  }

  /// Check if cache entry is valid
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    final now = DateTime.now();
    final diff = now.difference(timestamp).inSeconds;
    return diff < _cacheTTL;
  }

  /// Invalidate event caches related to an event
  void _invalidateEventCaches(Event event) {
    final keysToRemove = <String>[];

    for (final key in _eventCache.keys) {
      if (key.contains('practice_events_') ||
          key.contains('player_events_${event.player.id}')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _eventCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Invalidate all event caches
  void _invalidateAllEventCaches() {
    final keysToRemove = <String>[];

    for (final key in _eventCache.keys) {
      if (key.contains('practice_events_') || key.contains('player_events_')) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _eventCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Clear all caches
  void clearAllCaches() {
    _playerCache.clear();
    _teamCache.clear();
    _practiceCache.clear();
    _matchCache.clear();
    _eventCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'players': _playerCache.length,
      'teams': _teamCache.length,
      'practices': _practiceCache.length,
      'matches': _matchCache.length,
      'events': _eventCache.length,
      'total_entries': _cacheTimestamps.length,
    };
  }
}
