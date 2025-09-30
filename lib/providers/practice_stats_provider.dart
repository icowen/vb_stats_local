import 'package:flutter/foundation.dart';
import '../models/practice.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../services/player_service.dart';
import '../services/event_service.dart';

class PracticeStatsProvider extends ChangeNotifier {
  final PlayerService _playerService = PlayerService();
  final EventService _eventService = EventService();

  // Core data
  List<Player> _teamPlayers = [];
  List<Player> _allPlayers = [];
  List<Event> _teamEvents = [];
  Practice? _practice;

  // Loading states
  bool _isLoading = true;
  bool _isLoadingPlayers = false;
  bool _isLoadingEvents = false;

  // Error states
  String? _error;

  // Cache
  Map<int, List<Event>> _playerEventsCache = {};
  bool _cacheInitialized = false;

  // Getters
  List<Player> get teamPlayers => _teamPlayers;
  List<Player> get allPlayers => _allPlayers;
  List<Event> get teamEvents => _teamEvents;
  Practice? get practice => _practice;
  bool get isLoading => _isLoading;
  bool get isLoadingPlayers => _isLoadingPlayers;
  bool get isLoadingEvents => _isLoadingEvents;
  String? get error => _error;
  bool get hasData => _teamPlayers.isNotEmpty && _teamEvents.isNotEmpty;

  // Initialize with practice
  Future<void> initializeWithPractice(Practice practice) async {
    _practice = practice;
    _setLoading(true);
    _clearError();

    try {
      await _loadAllData();
    } catch (e) {
      _setError('Failed to load practice data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load all data in parallel
  Future<void> _loadAllData() async {
    if (_practice?.id == null) return;

    final futures = await Future.wait([_loadPlayers(), _loadEvents()]);

    // Initialize cache after loading
    await _initializeCache();
  }

  // Load players data
  Future<void> _loadPlayers() async {
    if (_practice?.id == null) return;

    _setLoadingPlayers(true);
    try {
      final practicePlayers = await _playerService.getPracticePlayers(
        _practice!.id!,
      );
      final allPlayers = await _playerService.getAllPlayers();

      _teamPlayers = _sortPlayers(practicePlayers);
      _allPlayers = allPlayers;

      notifyListeners();
    } catch (e) {
      _setError('Failed to load players: $e');
    } finally {
      _setLoadingPlayers(false);
    }
  }

  // Load events data
  Future<void> _loadEvents() async {
    if (_practice?.id == null) return;

    _setLoadingEvents(true);
    try {
      final events = await _eventService.getEventsForPractice(_practice!.id!);
      _teamEvents = events;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load events: $e');
    } finally {
      _setLoadingEvents(false);
    }
  }

  // Initialize cache for all players
  Future<void> _initializeCache() async {
    if (_cacheInitialized) return;

    _setLoading(true);
    try {
      // Batch load all player events
      final futures = _teamPlayers.map((player) async {
        if (player.id != null) {
          final events = await _eventService.getEventsForPlayer(player.id!);
          _playerEventsCache[player.id!] = events;
        }
      });

      await Future.wait(futures);
      _cacheInitialized = true;
    } catch (e) {
      _setError('Failed to initialize cache: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get player events (from cache or load)
  List<Event> getPlayerEvents(int playerId) {
    return _playerEventsCache[playerId] ?? [];
  }

  // Add event and update cache
  Future<void> addEvent(Event event) async {
    try {
      await _eventService.insertEvent(event);
      _teamEvents.add(event);

      // Update cache if it's a player event
      if (event.player.id != null) {
        _playerEventsCache[event.player.id!]?.add(event);
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to add event: $e');
    }
  }

  // Update event and cache
  Future<void> updateEvent(Event event) async {
    try {
      await _eventService.updateEvent(event);

      // Update in team events
      final index = _teamEvents.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _teamEvents[index] = event;
      }

      // Update in cache
      if (event.player.id != null) {
        final cacheIndex = _playerEventsCache[event.player.id!]?.indexWhere(
          (e) => e.id == event.id,
        );
        if (cacheIndex != null && cacheIndex != -1) {
          _playerEventsCache[event.player.id!]![cacheIndex] = event;
        }
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to update event: $e');
    }
  }

  // Delete event and update cache
  Future<void> deleteEvent(int eventId) async {
    try {
      await _eventService.deleteEvent(eventId);

      // Remove from team events
      final removedEvent = _teamEvents.firstWhere((e) => e.id == eventId);
      _teamEvents.removeWhere((e) => e.id == eventId);

      // Remove from cache
      if (removedEvent.player.id != null) {
        _playerEventsCache[removedEvent.player.id!]?.removeWhere(
          (e) => e.id == eventId,
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to delete event: $e');
    }
  }

  // Add player to practice
  Future<void> addPlayerToPractice(Player player) async {
    try {
      await _playerService.addPlayerToPractice(_practice!.id!, player.id!);
      _teamPlayers.add(player);
      _teamPlayers = _sortPlayers(_teamPlayers);

      // Initialize cache for new player
      if (player.id != null) {
        final events = await _eventService.getEventsForPlayer(player.id!);
        _playerEventsCache[player.id!] = events;
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to add player: $e');
    }
  }

  // Remove player from practice
  Future<void> removePlayerFromPractice(Player player) async {
    try {
      await _playerService.removePlayerFromPractice(_practice!.id!, player.id!);
      _teamPlayers.removeWhere((p) => p.id == player.id);

      // Remove from cache
      if (player.id != null) {
        _playerEventsCache.remove(player.id);
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to remove player: $e');
    }
  }

  // Sort players by jersey number, then name
  List<Player> _sortPlayers(List<Player> players) {
    final sortedPlayers = List<Player>.from(players);
    sortedPlayers.sort((a, b) {
      // First sort by jersey number (nulls last)
      final aJersey = a.jerseyNumber;
      final bJersey = b.jerseyNumber;

      if (aJersey == null && bJersey == null) {
        // Both null, sort by first name
      } else if (aJersey == null) {
        return 1; // a comes after b
      } else if (bJersey == null) {
        return -1; // a comes before b
      } else {
        final jerseyCompare = aJersey.compareTo(bJersey);
        if (jerseyCompare != 0) return jerseyCompare;
      }

      // Then sort by first name
      final aFirstName = a.firstName ?? '';
      final bFirstName = b.firstName ?? '';
      final firstNameCompare = aFirstName.compareTo(bFirstName);
      if (firstNameCompare != 0) return firstNameCompare;

      // Finally sort by last name
      final aLastName = a.lastName ?? '';
      final bLastName = b.lastName ?? '';
      return aLastName.compareTo(bLastName);
    });
    return sortedPlayers;
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setLoadingPlayers(bool loading) {
    _isLoadingPlayers = loading;
    notifyListeners();
  }

  void _setLoadingEvents(bool loading) {
    _isLoadingEvents = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    super.dispose();
  }
}
