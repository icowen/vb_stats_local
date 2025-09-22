import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'models/player.dart';
import 'models/event.dart';

class TeamStatsTable {
  static Map<String, double> calculateColumnWidths(
    List<Player> teamPlayers,
    List<Event> teamEvents,
    Function(List<Event>) getPlayerServingStats,
    Function(List<Event>) getPlayerPassingStats,
    Function(List<Event>) getPlayerAttackingStats,
  ) {
    Map<String, double> widths = {};

    // Player Info columns
    double maxPlayerNameLength = 'Player'.length.toDouble();
    double maxJerseyLength = 'Jersey'.length.toDouble();

    for (var player in teamPlayers) {
      maxPlayerNameLength = math.max(
        maxPlayerNameLength,
        player.fullName.length.toDouble(),
      );
      maxJerseyLength = math.max(
        maxJerseyLength,
        player.jerseyDisplay.length.toDouble(),
      );
    }

    widths['Player'] = math.max(
      (maxPlayerNameLength * 8) + 16, // 8 pixels per character + padding
      40.0, // Minimum width
    );
    widths['Jersey'] = math.max(
      (maxJerseyLength * 8) + 16,
      40.0, // Minimum width
    );

    // Serving columns
    List<String> servingHeaders = [
      'Serves',
      'Aces',
      'In',
      'Errors',
      'Float',
      'Hybrid',
      'Spin',
    ];
    for (String header in servingHeaders) {
      double maxLength = header.length.toDouble();
      for (var player in teamPlayers) {
        final playerEvents = teamEvents
            .where((e) => e.player.id == player.id)
            .toList();
        final stats = getPlayerServingStats(playerEvents);
        String value = '';
        switch (header) {
          case 'Serves':
            value = '${stats['total']}';
            break;
          case 'Aces':
            value = '${stats['ace'] ?? 0}';
            break;
          case 'In':
            value = '${stats['in']}';
            break;
          case 'Errors':
            value = '${stats['error']}';
            break;
          case 'Float':
            value = '${stats['float']}';
            break;
          case 'Hybrid':
            value = '${stats['hybrid']}';
            break;
          case 'Spin':
            value = '${stats['spin']}';
            break;
        }
        maxLength = math.max(maxLength, value.length.toDouble());
      }
      // Set minimum width
      double minWidth = 40.0; // Minimum width for all columns
      widths[header] = math.max((maxLength * 8) + 16, minWidth);
    }

    // Passing columns
    List<String> passingHeaders = [
      'Passes',
      'Average',
      'Ace',
      '0',
      '1',
      '2',
      '3',
    ];
    for (String header in passingHeaders) {
      double maxLength = header.length.toDouble();
      for (var player in teamPlayers) {
        final playerEvents = teamEvents
            .where((e) => e.player.id == player.id)
            .toList();
        final stats = getPlayerPassingStats(playerEvents);
        String value = '';
        switch (header) {
          case 'Passes':
            value = '${stats['total']}';
            break;
          case 'Average':
            value = '${stats['average'].toStringAsFixed(2)}';
            break;
          case 'Ace':
            value = '${stats['ace']}';
            break;
          case '0':
            value = '${stats['0']}';
            break;
          case '1':
            value = '${stats['1']}';
            break;
          case '2':
            value = '${stats['2']}';
            break;
          case '3':
            value = '${stats['3']}';
            break;
        }
        maxLength = math.max(maxLength, value.length.toDouble());
      }
      // Set minimum width
      double minWidth = 40.0; // Minimum width for all columns
      widths[header] = math.max((maxLength * 8) + 16, minWidth);
    }

    // Attacking columns
    List<String> attackingHeaders = [
      'Attacks',
      'Kills',
      'In',
      'Errors',
      'Hit %',
    ];
    for (String header in attackingHeaders) {
      double maxLength = header.length.toDouble();
      for (var player in teamPlayers) {
        final playerEvents = teamEvents
            .where((e) => e.player.id == player.id)
            .toList();
        final stats = getPlayerAttackingStats(playerEvents);
        String value = '';
        switch (header) {
          case 'Attacks':
            value = '${stats['total']}';
            break;
          case 'Kills':
            value = '${stats['kill']}';
            break;
          case 'In':
            value = '${stats['in']}';
            break;
          case 'Errors':
            value = '${stats['error']}';
            break;
          case 'Hit %':
            final total = stats['total'] as int;
            final kill = stats['kill'] as int;
            final error = stats['error'] as int;
            final hitPercentage = total > 0 ? (kill - error) / total : 0.0;
            value =
                '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';
            break;
        }
        maxLength = math.max(maxLength, value.length.toDouble());
      }
      // Set minimum width
      double minWidth = 40.0; // Minimum width for all columns
      widths[header] = math.max((maxLength * 8) + 16, minWidth);
    }

    return widths;
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
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth:
                MediaQuery.of(context).size.width -
                40, // Full screen width minus padding
          ),
          child: Column(
            children: [
              // Data Table with Group Borders
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Player Info Group
                    Container(
                      width: columnWidths['Player']! + columnWidths['Jersey']!,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF00E5FF),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Group Label
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withOpacity(0.2),
                                border: const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFF00E5FF),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Player Info',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00E5FF),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Data Table
                            DataTable(
                              columnSpacing: 0,
                              horizontalMargin: 0,
                              columns: [
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Player']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Player']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Player',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Jersey']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Jersey']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Jersey',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              rows: teamPlayers.map((player) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              player.fullName,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              player.jerseyDisplay,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Serving Stats Group
                    Container(
                      width:
                          columnWidths['Serves']! +
                          columnWidths['Aces']! +
                          columnWidths['In']! +
                          columnWidths['Errors']! +
                          columnWidths['Float']! +
                          columnWidths['Hybrid']! +
                          columnWidths['Spin']!,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF00FF88),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Group Label
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF88).withOpacity(0.2),
                                border: const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFF00FF88),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Serving',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00FF88),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Data Table
                            DataTable(
                              columnSpacing: 0,
                              horizontalMargin: 0,
                              columns: [
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Serves']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Serves']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Serves',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Aces']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Aces']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Aces',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['In']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['In']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Errors']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Errors']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Errors',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Float']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Float']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Float',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Hybrid']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Hybrid']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Hybrid',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Spin']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Spin']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Spin',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              rows: teamPlayers.map((player) {
                                final playerEvents = teamEvents
                                    .where((e) => e.player.id == player.id)
                                    .toList();
                                final servingStats = getPlayerServingStats(
                                  playerEvents,
                                );

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              servingStats['total'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              (servingStats['ace'] ?? 0)
                                                  .toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              servingStats['in'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              servingStats['error'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              servingStats['float'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              servingStats['hybrid'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              servingStats['spin'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Passing Stats Group
                    Container(
                      width:
                          columnWidths['Passes']! +
                          columnWidths['Average']! +
                          columnWidths['Ace']! +
                          columnWidths['0']! +
                          columnWidths['1']! +
                          columnWidths['2']! +
                          columnWidths['3']!,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF00E5FF),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Group Label
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withOpacity(0.2),
                                border: const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFF00E5FF),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Passing',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00E5FF),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Data Table
                            DataTable(
                              columnSpacing: 0,
                              horizontalMargin: 0,
                              columns: [
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Passes']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Passes']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Passes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Average']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Average']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Average',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Ace']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Ace']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Ace',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['0']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['0']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      '0',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['1']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['1']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      '1',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['2']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['2']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      '2',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['3']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['3']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      '3',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              rows: teamPlayers.map((player) {
                                final playerEvents = teamEvents
                                    .where((e) => e.player.id == player.id)
                                    .toList();
                                final passingStats = getPlayerPassingStats(
                                  playerEvents,
                                );

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              passingStats['total'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              (passingStats['average']
                                                      as double)
                                                  .toStringAsFixed(2),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              passingStats['ace'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              passingStats['0'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              passingStats['1'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              passingStats['2'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              passingStats['3'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Attacking Stats Group
                    Container(
                      width:
                          columnWidths['Attacks']! +
                          columnWidths['Kills']! +
                          columnWidths['In']! +
                          columnWidths['Errors']! +
                          columnWidths['Hit %']!,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF0097A7),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Group Label
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0097A7).withOpacity(0.2),
                                border: const Border(
                                  bottom: BorderSide(
                                    color: Color(0xFF0097A7),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Attacking',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0097A7),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // Data Table
                            DataTable(
                              columnSpacing: 0,
                              horizontalMargin: 0,
                              columns: [
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Attacks']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Attacks']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Attacks',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Kills']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Kills']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Kills',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['In']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['In']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Errors']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Errors']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Errors',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  columnWidth: FixedColumnWidth(
                                    columnWidths['Hit %']!,
                                  ),
                                  label: Container(
                                    width: columnWidths['Hit %']!,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'Hit %',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              rows: teamPlayers.map((player) {
                                final playerEvents = teamEvents
                                    .where((e) => e.player.id == player.id)
                                    .toList();
                                final attackingStats = getPlayerAttackingStats(
                                  playerEvents,
                                );
                                final total = attackingStats['total'] as int;
                                final kill = attackingStats['kill'] as int;
                                final error = attackingStats['error'] as int;
                                final hitPercentage = total > 0
                                    ? (kill - error) / total
                                    : 0.0;
                                final hitPercentageString =
                                    '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              attackingStats['total']
                                                  .toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              attackingStats['kill'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              attackingStats['in'].toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              attackingStats['error']
                                                  .toString(),
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              hitPercentageString,
                                              textAlign: TextAlign.center,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
