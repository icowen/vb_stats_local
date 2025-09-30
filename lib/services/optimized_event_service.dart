import '../models/event.dart';
import 'optimized_database_service.dart';

/// Optimized event service using caching and batch operations
class OptimizedEventService {
  static final OptimizedEventService _instance =
      OptimizedEventService._internal();
  factory OptimizedEventService() => _instance;
  OptimizedEventService._internal();

  final OptimizedDatabaseService _dbService = OptimizedDatabaseService();

  /// Insert a single event
  Future<int> insertEvent(Event event) async {
    return await _dbService.insertEvent(event);
  }

  /// Update an event
  Future<int> updateEvent(Event event) async {
    return await _dbService.updateEvent(event);
  }

  /// Delete an event
  Future<int> deleteEvent(int eventId) async {
    return await _dbService.deleteEvent(eventId);
  }

  /// Get all events (use with caution - can be expensive)
  Future<List<Event>> getAllEvents() async {
    // This is expensive, so we'll implement it only if needed
    throw UnimplementedError(
      'getAllEvents is too expensive - use getEventsForPractice or getEventsForPlayer instead',
    );
  }

  /// Get events for a specific practice
  Future<List<Event>> getEventsForPractice(int practiceId) async {
    return await _dbService.getEventsForPractice(practiceId);
  }

  /// Get events for a specific player
  Future<List<Event>> getEventsForPlayer(int playerId) async {
    return await _dbService.getEventsForPlayer(playerId);
  }

  /// Get events for multiple players (batch operation)
  Future<Map<int, List<Event>>> getEventsForPlayers(List<int> playerIds) async {
    final Map<int, List<Event>> results = {};

    // Load events for all players in parallel
    final futures = playerIds.map((id) => getEventsForPlayer(id));
    final eventLists = await Future.wait(futures);

    for (int i = 0; i < playerIds.length; i++) {
      results[playerIds[i]] = eventLists[i];
    }

    return results;
  }

  /// Get events for a specific player in a specific practice
  Future<List<Event>> getEventsForPlayerInPractice(
    int playerId,
    int practiceId,
  ) async {
    final allPlayerEvents = await getEventsForPlayer(playerId);
    return allPlayerEvents
        .where((event) => event.practice?.id == practiceId)
        .toList();
  }

  /// Get events for multiple practices (batch operation)
  Future<Map<int, List<Event>>> getEventsForPractices(
    List<int> practiceIds,
  ) async {
    final Map<int, List<Event>> results = {};

    // Load events for all practices in parallel
    final futures = practiceIds.map((id) => getEventsForPractice(id));
    final eventLists = await Future.wait(futures);

    for (int i = 0; i < practiceIds.length; i++) {
      results[practiceIds[i]] = eventLists[i];
    }

    return results;
  }

  /// Batch insert multiple events
  Future<void> batchInsertEvents(List<Event> events) async {
    await _dbService.batchInsertEvents(events);
  }

  /// Get events by type for a practice
  Future<List<Event>> getEventsByTypeForPractice(
    int practiceId,
    String eventType,
  ) async {
    final allEvents = await getEventsForPractice(practiceId);
    return allEvents.where((event) => event.type.name == eventType).toList();
  }

  /// Get events by type for a player
  Future<List<Event>> getEventsByTypeForPlayer(
    int playerId,
    String eventType,
  ) async {
    final allEvents = await getEventsForPlayer(playerId);
    return allEvents.where((event) => event.type.name == eventType).toList();
  }

  /// Get events with coordinates for a practice
  Future<List<Event>> getEventsWithCoordinatesForPractice(
    int practiceId,
  ) async {
    final allEvents = await getEventsForPractice(practiceId);
    return allEvents.where((event) => event.hasCoordinates).toList();
  }

  /// Get events with coordinates for a player
  Future<List<Event>> getEventsWithCoordinatesForPlayer(int playerId) async {
    final allEvents = await getEventsForPlayer(playerId);
    return allEvents.where((event) => event.hasCoordinates).toList();
  }

  /// Get recent events for a practice (last N events)
  Future<List<Event>> getRecentEventsForPractice(
    int practiceId,
    int limit,
  ) async {
    final allEvents = await getEventsForPractice(practiceId);
    return allEvents.take(limit).toList();
  }

  /// Get recent events for a player (last N events)
  Future<List<Event>> getRecentEventsForPlayer(int playerId, int limit) async {
    final allEvents = await getEventsForPlayer(playerId);
    return allEvents.take(limit).toList();
  }

  /// Get event statistics for a practice
  Future<Map<String, int>> getEventStatsForPractice(int practiceId) async {
    final events = await getEventsForPractice(practiceId);
    final stats = <String, int>{};

    for (final event in events) {
      final type = event.type.name;
      stats[type] = (stats[type] ?? 0) + 1;
    }

    return stats;
  }

  /// Get event statistics for a player
  Future<Map<String, int>> getEventStatsForPlayer(int playerId) async {
    final events = await getEventsForPlayer(playerId);
    final stats = <String, int>{};

    for (final event in events) {
      final type = event.type.name;
      stats[type] = (stats[type] ?? 0) + 1;
    }

    return stats;
  }

  /// Get event statistics for multiple players (batch operation)
  Future<Map<int, Map<String, int>>> getEventStatsForPlayers(
    List<int> playerIds,
  ) async {
    final Map<int, Map<String, int>> results = {};

    // Load stats for all players in parallel
    final futures = playerIds.map((id) => getEventStatsForPlayer(id));
    final statsLists = await Future.wait(futures);

    for (int i = 0; i < playerIds.length; i++) {
      results[playerIds[i]] = statsLists[i];
    }

    return results;
  }

  /// Clear all caches
  void clearCaches() {
    _dbService.clearAllCaches();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return _dbService.getCacheStats();
  }
}
