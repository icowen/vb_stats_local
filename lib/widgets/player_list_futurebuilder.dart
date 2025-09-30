import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/player_selection_provider.dart';

class PlayerListFutureBuilder extends StatelessWidget {
  final List<Player> teamPlayers;
  final List<Player> allPlayers;
  final Function(Player) onPlayerTap;
  final Function() onAddPlayer;
  final Function() onAddTeam;
  final Function(Player) onRemovePlayer;
  final Function(String, int?) isPlayerOnCourt;
  final Function() hasAnyPlayersOnCourt;

  const PlayerListFutureBuilder({
    super.key,
    required this.teamPlayers,
    required this.allPlayers,
    required this.onPlayerTap,
    required this.onAddPlayer,
    required this.onAddTeam,
    required this.onRemovePlayer,
    required this.isPlayerOnCourt,
    required this.hasAnyPlayersOnCourt,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerSelectionProvider>(
      builder: (context, selectionProvider, child) {
        final selectedPlayer = selectionProvider.selectedPlayer;

        return Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey[600]!, width: 1),
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
                  'Players',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00E5FF),
                  ),
                ),
              ),

              // Add Player and Team Buttons
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAddPlayer,
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text(
                          'Add Player',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAddTeam,
                        icon: const Icon(Icons.group_add, size: 16),
                        label: const Text(
                          'Add Team',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Players List
              Expanded(
                child: teamPlayers.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No players yet.\nTap "Add Player" to start.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: teamPlayers.length,
                        itemBuilder: (context, index) {
                          final player = teamPlayers[index];
                          final isSelected = selectedPlayer?.id == player.id;
                          final isOnCourt =
                              player.id != null &&
                              isPlayerOnCourt(player.id.toString(), player.id);
                          final hasPlayersOnCourt = hasAnyPlayersOnCourt();

                          // Determine styling based on selection and court status
                          Color? backgroundColor;
                          Color borderColor;
                          double opacity = 1.0;

                          if (isSelected) {
                            backgroundColor = const Color(
                              0xFF00E5FF,
                            ).withOpacity(0.1);
                            borderColor = const Color(0xFF00E5FF);
                          } else if (hasPlayersOnCourt && !isOnCourt) {
                            // Players not on court when others are on court
                            backgroundColor = null;
                            borderColor = Colors.grey[400]!;
                            opacity = 0.6;
                          } else if (hasPlayersOnCourt && isOnCourt) {
                            // Players on court when others are on court
                            backgroundColor = null;
                            borderColor = Colors.grey[600]!;
                          } else {
                            // Default styling when no players on court
                            backgroundColor = null;
                            borderColor = Colors.grey[700]!;
                          }

                          return Opacity(
                            opacity: opacity,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                border: Border.all(
                                  color: borderColor,
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
                                  backgroundColor: const Color(0xFF00E5FF),
                                  child: Text(
                                    '${player.jerseyNumber ?? '?'}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  player.fullName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => onRemovePlayer(player),
                                  tooltip: 'Remove from practice',
                                ),
                                onTap: () => onPlayerTap(player),
                              ),
                            ),
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
}
