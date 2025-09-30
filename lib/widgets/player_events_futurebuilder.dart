import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../providers/player_selection_provider.dart';

class PlayerEventsFutureBuilder extends StatelessWidget {
  final Player? selectedPlayer;
  final Function(Event) onEditEvent;
  final Function(Event) onDeleteEvent;
  final Map<int, List<Event>> playerEventsCache;

  const PlayerEventsFutureBuilder({
    super.key,
    required this.selectedPlayer,
    required this.onEditEvent,
    required this.onDeleteEvent,
    required this.playerEventsCache,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerSelectionProvider>(
      builder: (context, selectionProvider, child) {
        final selectedPlayer = selectionProvider.selectedPlayer;

        if (selectedPlayer == null) {
          return Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey[600]!, width: 1),
              ),
            ),
            child: const Center(
              child: Text(
                'Select a player to view their events',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey[600]!, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[600]!, width: 1),
                  ),
                ),
                child: Text(
                  'Events - ${selectedPlayer.fullName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00FF88),
                  ),
                ),
              ),

              // Events List with FutureBuilder
              Expanded(
                child: FutureBuilder<List<Event>>(
                  future: _loadPlayerEvents(selectedPlayer),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00FF88),
                          strokeWidth: 2,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error loading events',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                // Trigger rebuild to retry
                                (context as Element).markNeedsBuild();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final events = snapshot.data ?? [];

                    if (events.isEmpty) {
                      return const Center(
                        child: Text(
                          'No events recorded yet',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[700]!,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: _getEventTypeColor(
                                event.type.name,
                              ),
                              child: Text(
                                event.type.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            title: Text(
                              event.type.displayName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              _formatEventDetails(event),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Color(0xFF00E5FF),
                                  ),
                                  onPressed: () => onEditEvent(event),
                                  tooltip: 'Edit event',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => onDeleteEvent(event),
                                  tooltip: 'Delete event',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Event>> _loadPlayerEvents(Player player) async {
    if (player.id == null) return [];

    // Check cache first
    if (playerEventsCache.containsKey(player.id!)) {
      return playerEventsCache[player.id!]!;
    }

    try {
      final eventService = EventService();
      final events = await eventService.getEventsForPlayer(player.id!);
      // Update cache
      playerEventsCache[player.id!] = events;
      return events;
    } catch (e) {
      print('Error loading player events: $e');
      return [];
    }
  }

  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'serve':
        return const Color(0xFF00E5FF);
      case 'pass':
        return const Color(0xFF00FF88);
      case 'attack':
        return const Color(0xFFFF6B6B);
      case 'block':
        return const Color(0xFFFFD93D);
      case 'dig':
        return const Color(0xFF6BCF7F);
      case 'set':
        return const Color(0xFF9B59B6);
      case 'freeball':
        return const Color(0xFFFF9500);
      default:
        return Colors.grey;
    }
  }

  String _formatEventDetails(Event event) {
    final details = <String>[];

    // Add result if available
    if (event.metadata.containsKey('result')) {
      details.add('Result: ${event.metadata['result']}');
    }

    // Add rating if available
    if (event.metadata.containsKey('rating')) {
      details.add('Rating: ${event.metadata['rating']}');
    }

    // Add coordinates if available
    if (event.hasCoordinates) {
      details.add('Coords: ${event.coordinateInfo}');
    }

    return details.join(' • ');
  }
}
