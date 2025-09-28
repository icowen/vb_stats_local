import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/practice.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../utils/date_utils.dart';

class PdfService {
  static Future<String> generatePracticeAnalysisPDF({
    required Practice practice,
    required List<Player> practicePlayers,
    required List<Event> teamEvents,
    required Map<String, dynamic> Function(Player) getPlayerServingStats,
    required Map<String, dynamic> Function(Player) getPlayerPassingStats,
    required Map<String, dynamic> Function(Player) getPlayerAttackingStats,
  }) async {
    final pdf = pw.Document();

    // Add Cover Page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Practice Analysis Report',
                  style: pw.TextStyle(
                    fontSize: 36,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  practice.practiceTitle,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Date: ${DateFormatter.formatDate(practice.date)}',
                  style: const pw.TextStyle(fontSize: 18),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Team: ${practice.team.teamName}',
                  style: const pw.TextStyle(fontSize: 18),
                ),
                pw.SizedBox(height: 50),
                pw.Text(
                  'Generated on: ${DateFormatter.formatDate(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add Player Statistics Table
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              'Player Statistics',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildPlayerStatsTable(
            practicePlayers,
            getPlayerServingStats,
            getPlayerPassingStats,
            getPlayerAttackingStats,
          ),
        ],
      ),
    );

    // Add Court Visualizations for each player/action combination
    final actionTypes = EventType.values;
    for (final actionType in actionTypes) {
      final eventsForAction = teamEvents
          .where((e) => e.type == actionType)
          .toList();
      if (eventsForAction.isNotEmpty) {
        // Group by player
        final eventsByPlayer = <Player, List<Event>>{};
        for (final event in eventsForAction) {
          eventsByPlayer.putIfAbsent(event.player, () => []).add(event);
        }

        // Create a page for each player with this action type
        for (final entry in eventsByPlayer.entries) {
          final player = entry.key;
          final playerEvents = entry.value;

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header with player name and action type
                    pw.Text(
                      '${player.fullName} - ${actionType.displayName} Visualization',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      '${playerEvents.length} events recorded',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 10),

                    // Player stats for this action type
                    _buildPlayerActionStats(
                      player,
                      actionType,
                      getPlayerServingStats,
                      getPlayerPassingStats,
                      getPlayerAttackingStats,
                    ),
                    pw.SizedBox(height: 20),

                    // Court visualization
                    pw.Expanded(
                      child: pw.Center(
                        child: _buildCourtVisualization(
                          playerEvents,
                          actionType,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }
      }
    }

    // Save PDF to Downloads directory
    final externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception('Could not access external storage directory');
    }

    // Create Downloads directory path
    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final fileName =
        'practice_analysis_${practice.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${downloadsDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // Log the save location for debugging
    print('=== PDF SAVE LOCATION DEBUG ===');
    print('External Storage Directory: ${externalDir.path}');
    print('Downloads Directory: ${downloadsDir.path}');
    print('Downloads Directory Exists: ${await downloadsDir.exists()}');
    print('File Name: $fileName');
    print('Full File Path: $filePath');
    print('File Exists: ${await file.exists()}');
    print('File Size: ${await file.length()} bytes');
    print('================================');

    return filePath;
  }

  static pw.Widget _buildPlayerStatsTable(
    List<Player> players,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
    Map<String, dynamic> Function(Player) getPlayerAttackingStats,
  ) {
    final tableHeaders = [
      'Player',
      'Jersey',
      'S.Ace',
      'S.In',
      'S.Err',
      'P.Ace',
      'P.3',
      'P.2',
      'P.1',
      'P.0',
      'A.Kill',
      'A.In',
      'A.Err',
      'Hit %',
    ];

    return pw.Table.fromTextArray(
      headers: tableHeaders,
      data: players.map((player) {
        final servingStats = getPlayerServingStats(player);
        final passingStats = getPlayerPassingStats(player);
        final attackingStats = getPlayerAttackingStats(player);

        final totalAttacks =
            (attackingStats['kill'] ?? 0) +
            (attackingStats['in'] ?? 0) +
            (attackingStats['error'] ?? 0);
        final kills = attackingStats['kill'] ?? 0;
        final errors = attackingStats['error'] ?? 0;
        final hitPercentage = totalAttacks > 0
            ? (kills - errors) / totalAttacks
            : 0.0;

        return [
          player.fullName,
          player.jerseyNumber?.toString() ?? '-',
          (servingStats['ace'] ?? 0).toString(),
          (servingStats['in'] ?? 0).toString(),
          (servingStats['error'] ?? 0).toString(),
          (passingStats['ace'] ?? 0).toString(),
          (passingStats['3'] ?? 0).toString(),
          (passingStats['2'] ?? 0).toString(),
          (passingStats['1'] ?? 0).toString(),
          (passingStats['0'] ?? 0).toString(),
          (attackingStats['kill'] ?? 0).toString(),
          (attackingStats['in'] ?? 0).toString(),
          (attackingStats['error'] ?? 0).toString(),
          _formatHitPercentage(hitPercentage),
        ];
      }).toList(),
      cellAlignment: pw.Alignment.center,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 9),
      border: pw.TableBorder.all(color: PdfColors.grey),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Player
        1: const pw.FlexColumnWidth(1), // Jersey
        2: const pw.FlexColumnWidth(1), // S.Ace
        3: const pw.FlexColumnWidth(1), // S.In
        4: const pw.FlexColumnWidth(1), // S.Err
        5: const pw.FlexColumnWidth(1), // P.Ace
        6: const pw.FlexColumnWidth(1), // P.3
        7: const pw.FlexColumnWidth(1), // P.2
        8: const pw.FlexColumnWidth(1), // P.1
        9: const pw.FlexColumnWidth(1), // P.0
        10: const pw.FlexColumnWidth(1), // A.Kill
        11: const pw.FlexColumnWidth(1), // A.In
        12: const pw.FlexColumnWidth(1), // A.Err
        13: const pw.FlexColumnWidth(1.5), // Hit %
      },
    );
  }

  static String _formatHitPercentage(double hitPercentage) {
    if (hitPercentage >= 1.0) {
      return '1.000';
    } else if (hitPercentage < 0) {
      return '-.${(hitPercentage.abs() * 1000).round().toString().padLeft(3, '0')}';
    } else {
      return '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';
    }
  }

  static pw.Widget _buildPlayerActionStats(
    Player player,
    EventType actionType,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
    Map<String, dynamic> Function(Player) getPlayerAttackingStats,
  ) {
    switch (actionType) {
      case EventType.serve:
        final stats = getPlayerServingStats(player);
        return pw.Row(
          children: [
            pw.Text(
              'Serving Stats: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Aces: ${stats['ace'] ?? 0} | '),
            pw.Text('In: ${stats['in'] ?? 0} | '),
            pw.Text('Errors: ${stats['error'] ?? 0} | '),
            pw.Text('Total: ${stats['total'] ?? 0}'),
          ],
        );
      case EventType.pass:
        final stats = getPlayerPassingStats(player);
        return pw.Row(
          children: [
            pw.Text(
              'Passing Stats: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Aces: ${stats['ace'] ?? 0} | '),
            pw.Text('3s: ${stats['3'] ?? 0} | '),
            pw.Text('2s: ${stats['2'] ?? 0} | '),
            pw.Text('1s: ${stats['1'] ?? 0} | '),
            pw.Text('0s: ${stats['0'] ?? 0} | '),
            pw.Text(
              'Avg: ${_formatPassingAverage(stats['average'] as double? ?? 0.0)}',
            ),
          ],
        );
      case EventType.attack:
        final stats = getPlayerAttackingStats(player);
        final total = stats['total'] ?? 0;
        final kills = stats['kill'] ?? 0;
        final errors = stats['error'] ?? 0;
        final hitPercentage = total > 0 ? (kills - errors) / total : 0.0;
        return pw.Row(
          children: [
            pw.Text(
              'Attacking Stats: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Kills: ${kills} | '),
            pw.Text('In: ${stats['in'] ?? 0} | '),
            pw.Text('Errors: ${errors} | '),
            pw.Text('Total: ${total} | '),
            pw.Text('Hit %: ${_formatHitPercentage(hitPercentage)}'),
          ],
        );
      default:
        return pw.Text('Stats not available for ${actionType.displayName}');
    }
  }

  static String _formatPassingAverage(double average) {
    if (average >= 3.0) return '3.000';
    return average.toStringAsFixed(3);
  }

  static pw.Widget _buildCourtVisualization(
    List<Event> events,
    EventType actionType,
  ) {
    // Create SVG content for the court visualization
    final svgContent = _generateCourtSVG(events, actionType);

    return pw.Container(
      width: 600,
      height: 500,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          // Court header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(4),
            color: PdfColors.grey300,
            child: pw.Text(
              'Court Visualization - ${events.length} events',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          // SVG Court
          pw.Expanded(
            child: pw.Center(
              child: pw.SvgImage(svg: svgContent, width: 580, height: 450),
            ),
          ),
        ],
      ),
    );
  }

  static String _generateCourtSVG(List<Event> events, EventType actionType) {
    // Court dimensions (with 10ft zones around inner court)
    const double containerWidth = 580.0;
    const double containerHeight = 450.0;
    const double innerCourtWidth = 400.0; // Sideline to sideline
    const double innerCourtHeight = 300.0; // Endline to endline
    const double marginX = 90.0; // 10ft zone on left and right
    const double marginY = 75.0; // 10ft zone on top and bottom

    // Court positions
    const double courtLeft = marginX;
    const double courtTop = marginY;
    const double tenFootOffset = 60.0; // 10-foot line distance from net

    final StringBuffer svg = StringBuffer();
    svg.writeln(
      '<svg width="$containerWidth" height="$containerHeight" xmlns="http://www.w3.org/2000/svg">',
    );

    // Court background
    svg.writeln(
      '  <rect x="$courtLeft" y="$courtTop" width="$innerCourtWidth" height="$innerCourtHeight" fill="none" stroke="#00E5FF" stroke-width="2"/>',
    );

    // Net line (vertical, center of court)
    final double netX =
        courtLeft + (innerCourtWidth / 2); // Center of court horizontally
    final double courtBottom = courtTop + innerCourtHeight;
    svg.writeln(
      '  <line x1="$netX" y1="$courtTop" x2="$netX" y2="$courtBottom" stroke="#9C27B0" stroke-width="3"/>',
    );

    // 10-foot lines (vertical, 60px from net)
    final double leftTenFootX = netX - tenFootOffset;
    final double rightTenFootX = netX + tenFootOffset;
    svg.writeln(
      '  <line x1="$leftTenFootX" y1="$courtTop" x2="$leftTenFootX" y2="$courtBottom" stroke="#666666" stroke-width="2"/>',
    );
    svg.writeln(
      '  <line x1="$rightTenFootX" y1="$courtTop" x2="$rightTenFootX" y2="$courtBottom" stroke="#666666" stroke-width="2"/>',
    );

    // Events
    for (final event in events) {
      if (event.fromX != null && event.fromY != null) {
        // Map coordinates to court area (0,0 = top-left of inner court)
        final startX = courtLeft + (event.fromX! * innerCourtWidth);
        final startY = courtTop + (event.fromY! * innerCourtHeight);

        // Start point (green circle)
        svg.writeln(
          '  <circle cx="$startX" cy="$startY" r="8" fill="#00FF00" stroke="#000000" stroke-width="2"/>',
        );

        // End point and connection line
        if (event.toX != null && event.toY != null) {
          final endX = courtLeft + (event.toX! * innerCourtWidth);
          final endY = courtTop + (event.toY! * innerCourtHeight);

          // Connection line
          final lineColor = _getEventColorHex(actionType);
          svg.writeln(
            '  <line x1="$startX" y1="$startY" x2="$endX" y2="$endY" stroke="$lineColor" stroke-width="3"/>',
          );

          // End point (red X)
          svg.writeln(
            '  <rect x="${endX - 8}" y="${endY - 8}" width="16" height="16" fill="#FF0000"/>',
          );
          svg.writeln(
            '  <text x="$endX" y="${endY + 3}" text-anchor="middle" fill="white" font-size="10" font-weight="bold">X</text>',
          );
        }
      }
    }

    svg.writeln('</svg>');
    return svg.toString();
  }

  static String _getEventColorHex(EventType actionType) {
    switch (actionType) {
      case EventType.serve:
        return "#00E5FF"; // Light blue
      case EventType.pass:
        return "#00FF88"; // Light green
      case EventType.attack:
        return "#FF8800"; // Orange
      case EventType.block:
        return "#9C27B0"; // Purple
      case EventType.dig:
        return "#FF4444"; // Red
      case EventType.set:
        return "#FFFF00"; // Yellow
      case EventType.freeball:
        return "#00FF00"; // Bright green
    }
  }
}
