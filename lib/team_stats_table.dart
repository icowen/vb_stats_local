import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'models/player.dart';
import 'models/event.dart';
import 'sticky_table.dart';

class TeamStatsTable {
  static Map<String, double> calculateColumnWidths(
    List<Player> teamPlayers,
    List<Event> teamEvents,
    Function(List<Event>) getPlayerServingStats,
    Function(List<Event>) getPlayerPassingStats,
    Function(List<Event>) getPlayerAttackingStats,
  ) {
    // Calculate dynamic widths based on content
    double playerNameWidth = 80.0; // Base width for player names
    double jerseyWidth = 50.0; // Base width for jersey numbers

    // Calculate serving column widths
    double servesWidth = 60.0;
    double acesWidth = 50.0;
    double inWidth = 40.0;
    double errorsWidth = 60.0;
    double floatWidth = 50.0;
    double hybridWidth = 60.0;
    double spinWidth = 50.0;

    // Calculate passing column widths
    double passesWidth = 60.0;
    double averageWidth = 70.0;
    double aceWidth = 50.0;
    double zeroWidth = 40.0;
    double oneWidth = 40.0;
    double twoWidth = 40.0;
    double threeWidth = 40.0;

    // Calculate attacking column widths
    double attacksWidth = 70.0;
    double killsWidth = 50.0;
    double inAttacksWidth = 40.0;
    double errorsAttacksWidth = 60.0;
    double hitPercentWidth = 60.0;

    // Adjust widths based on actual content
    for (final player in teamPlayers) {
      final playerEvents = teamEvents
          .where((event) => event.player.id == player.id)
          .toList();

      final servingStats = getPlayerServingStats(playerEvents);
      final passingStats = getPlayerPassingStats(playerEvents);
      final attackingStats = getPlayerAttackingStats(playerEvents);

      // Player name width
      final nameLength = player.fullName.length;
      if (nameLength > 10) {
        playerNameWidth = math.max(playerNameWidth, nameLength * 6.0);
      }

      // Jersey width
      final jerseyLength = player.jerseyDisplay.length;
      if (jerseyLength > 3) {
        jerseyWidth = math.max(jerseyWidth, jerseyLength * 8.0);
      }

      // Serving stats widths
      servesWidth = math.max(
        servesWidth,
        servingStats['total'].toString().length * 8.0,
      );
      acesWidth = math.max(
        acesWidth,
        (servingStats['ace'] ?? 0).toString().length * 8.0,
      );
      inWidth = math.max(inWidth, servingStats['in'].toString().length * 8.0);
      errorsWidth = math.max(
        errorsWidth,
        servingStats['error'].toString().length * 8.0,
      );
      floatWidth = math.max(
        floatWidth,
        servingStats['float'].toString().length * 8.0,
      );
      hybridWidth = math.max(
        hybridWidth,
        servingStats['hybrid'].toString().length * 8.0,
      );
      spinWidth = math.max(
        spinWidth,
        servingStats['spin'].toString().length * 8.0,
      );

      // Passing stats widths
      passesWidth = math.max(
        passesWidth,
        passingStats['total'].toString().length * 8.0,
      );
      averageWidth = math.max(
        averageWidth,
        (passingStats['average'] as double).toStringAsFixed(2).length * 8.0,
      );
      aceWidth = math.max(
        aceWidth,
        passingStats['ace'].toString().length * 8.0,
      );
      zeroWidth = math.max(
        zeroWidth,
        passingStats['0'].toString().length * 8.0,
      );
      oneWidth = math.max(oneWidth, passingStats['1'].toString().length * 8.0);
      twoWidth = math.max(twoWidth, passingStats['2'].toString().length * 8.0);
      threeWidth = math.max(
        threeWidth,
        passingStats['3'].toString().length * 8.0,
      );

      // Attacking stats widths
      attacksWidth = math.max(
        attacksWidth,
        attackingStats['total'].toString().length * 8.0,
      );
      killsWidth = math.max(
        killsWidth,
        attackingStats['kill'].toString().length * 8.0,
      );
      inAttacksWidth = math.max(
        inAttacksWidth,
        attackingStats['in'].toString().length * 8.0,
      );
      errorsAttacksWidth = math.max(
        errorsAttacksWidth,
        attackingStats['error'].toString().length * 8.0,
      );

      final total = attackingStats['total'] as int;
      final kill = attackingStats['kill'] as int;
      final error = attackingStats['error'] as int;
      final hitPercentage = total > 0 ? (kill - error) / total : 0.0;
      final hitPercentageString =
          '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';
      hitPercentWidth = math.max(
        hitPercentWidth,
        hitPercentageString.length * 8.0,
      );
    }

    return {
      'Player': math.max(
        70.0,
        math.max(playerNameWidth, 'Player'.length * 10.0),
      ),
      'Jersey': math.max(70.0, math.max(jerseyWidth, 'Jersey'.length * 10.0)),
      'Serves': math.max(70.0, math.max(servesWidth, 'Serves'.length * 10.0)),
      'Aces': math.max(70.0, math.max(acesWidth, 'Aces'.length * 10.0)),
      'In': math.max(
        70.0,
        math.max(math.max(inWidth, inAttacksWidth), 'In'.length * 10.0),
      ),
      'Errors': math.max(
        70.0,
        math.max(
          math.max(errorsWidth, errorsAttacksWidth),
          'Errors'.length * 10.0,
        ),
      ),
      'Float': math.max(70.0, math.max(floatWidth, 'Float'.length * 10.0)),
      'Hybrid': math.max(70.0, math.max(hybridWidth, 'Hybrid'.length * 10.0)),
      'Spin': math.max(70.0, math.max(spinWidth, 'Spin'.length * 10.0)),
      'Passes': math.max(70.0, math.max(passesWidth, 'Passes'.length * 10.0)),
      'Average': math.max(
        70.0,
        math.max(averageWidth, 'Average'.length * 10.0),
      ),
      'Ace': math.max(70.0, math.max(aceWidth, 'Ace'.length * 10.0)),
      '0': math.max(70.0, math.max(zeroWidth, '0'.length * 10.0)),
      '1': math.max(70.0, math.max(oneWidth, '1'.length * 10.0)),
      '2': math.max(70.0, math.max(twoWidth, '2'.length * 10.0)),
      '3': math.max(70.0, math.max(threeWidth, '3'.length * 10.0)),
      'Attacks': math.max(
        70.0,
        math.max(attacksWidth, 'Attacks'.length * 10.0),
      ),
      'Kills': math.max(70.0, math.max(killsWidth, 'Kills'.length * 10.0)),
      'Hit %': math.max(70.0, math.max(hitPercentWidth, 'Hit %'.length * 10.0)),
    };
  }

  static Widget buildPlayerStatsTable(
    BuildContext context,
    Map<String, double> columnWidths,
    List<Player> teamPlayers,
    List<Event> teamEvents,
    Function(List<Event>) getPlayerServingStats,
    Function(List<Event>) getPlayerPassingStats,
    Function(List<Event>) getPlayerAttackingStats,
  ) {
    return StickyTable(
      columnWidths: columnWidths,
      teamPlayers: teamPlayers,
      teamEvents: teamEvents,
      getPlayerServingStats: getPlayerServingStats,
      getPlayerPassingStats: getPlayerPassingStats,
      getPlayerAttackingStats: getPlayerAttackingStats,
    );
  }
}
