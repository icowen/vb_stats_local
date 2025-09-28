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

    // Add cover page
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
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  practice.practiceTitle,
                  style: pw.TextStyle(fontSize: 18),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Date: ${DateFormatter.formatDate(practice.date)}',
                  style: pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Team: ${practice.team.teamName}',
                  style: pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Generated on: ${DateFormatter.formatDate(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Add player statistics table page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Player Statistics',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Expanded(
                child: _buildPlayerStatsTable(
                  practicePlayers,
                  getPlayerServingStats,
                  getPlayerPassingStats,
                  getPlayerAttackingStats,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Add court visualizations for each action type
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
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FixedColumnWidth(80), // Player
        1: const pw.FixedColumnWidth(50), // Jersey
        2: const pw.FixedColumnWidth(60), // Serve Ace
        3: const pw.FixedColumnWidth(60), // Serve In
        4: const pw.FixedColumnWidth(60), // Serve Error
        5: const pw.FixedColumnWidth(60), // Pass Ace
        6: const pw.FixedColumnWidth(60), // Pass 3
        7: const pw.FixedColumnWidth(60), // Pass 2
        8: const pw.FixedColumnWidth(60), // Pass 1
        9: const pw.FixedColumnWidth(60), // Pass 0
        10: const pw.FixedColumnWidth(60), // Attack Kill
        11: const pw.FixedColumnWidth(60), // Attack In
        12: const pw.FixedColumnWidth(60), // Attack Error
        13: const pw.FixedColumnWidth(80), // Hit %
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Player',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Jersey',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'S.Ace',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'S.In',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'S.Err',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'P.Ace',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'P.3',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'P.2',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'P.1',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'P.0',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'A.Kill',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'A.In',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'A.Err',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                'Hit %',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        // Data rows
        ...players.map((player) {
          final servingStats = getPlayerServingStats(player);
          final passingStats = getPlayerPassingStats(player);
          final attackingStats = getPlayerAttackingStats(player);

          final totalAttacks = attackingStats['total'] ?? 0;
          final kills = attackingStats['kill'] ?? 0;
          final errors = attackingStats['error'] ?? 0;
          final hitPercentage = totalAttacks > 0
              ? (kills - errors) / totalAttacks
              : 0.0;

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  player.fullName,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  player.jerseyNumber?.toString() ?? '-',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (servingStats['ace'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (servingStats['in'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (servingStats['error'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (passingStats['ace'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (passingStats['3'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (passingStats['2'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (passingStats['1'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (passingStats['0'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (attackingStats['kill'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (attackingStats['in'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  (attackingStats['error'] ?? 0).toString(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  _formatHitPercentage(hitPercentage),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
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
              child: pw.SvgImage(
                svg: svgContent,
                width: 580,
                height: 450,
              ),
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
    const double innerCourtWidth = 400.0;  // Sideline to sideline
    const double innerCourtHeight = 300.0; // Endline to endline
    const double marginX = 90.0; // 10ft zone on left and right
    const double marginY = 75.0; // 10ft zone on top and bottom
    
    // Court positions
    const double courtLeft = marginX;
    const double courtTop = marginY;
    const double courtRight = courtLeft + innerCourtWidth;
    const double courtBottom = courtTop + innerCourtHeight;
    const double netY = courtTop + (innerCourtHeight / 2); // Center of court
    const double tenFootOffset = 60.0; // 10-foot line distance from net
    
    final StringBuffer svg = StringBuffer();
    svg.writeln('<svg width="$containerWidth" height="$containerHeight" xmlns="http://www.w3.org/2000/svg">');
    
    // Court background
    svg.writeln('  <rect x="$courtLeft" y="$courtTop" width="$innerCourtWidth" height="$innerCourtHeight" fill="none" stroke="#00E5FF" stroke-width="2"/>');
    
    // Net line (horizontal, center of court)
    svg.writeln('  <line x1="$courtLeft" y1="$netY" x2="$courtRight" y2="$netY" stroke="#9C27B0" stroke-width="3"/>');
    
    // 10-foot lines (horizontal, 60px from net)
    final double leftTenFootY = netY - tenFootOffset;
    final double rightTenFootY = netY + tenFootOffset;
    svg.writeln('  <line x1="$courtLeft" y1="$leftTenFootY" x2="$courtRight" y2="$leftTenFootY" stroke="#666666" stroke-width="2"/>');
    svg.writeln('  <line x1="$courtLeft" y1="$rightTenFootY" x2="$courtRight" y2="$rightTenFootY" stroke="#666666" stroke-width="2"/>');
    
    // Events
    for (final event in events) {
      if (event.fromX != null && event.fromY != null) {
        // Map coordinates to court area (0,0 = top-left of inner court)
        final startX = courtLeft + (event.fromX! * innerCourtWidth);
        final startY = courtTop + (event.fromY! * innerCourtHeight);
        
        // Start point (green circle)
        svg.writeln('  <circle cx="$startX" cy="$startY" r="8" fill="#00FF00" stroke="#000000" stroke-width="2"/>');
        
        // End point and connection line
        if (event.toX != null && event.toY != null) {
          final endX = courtLeft + (event.toX! * innerCourtWidth);
          final endY = courtTop + (event.toY! * innerCourtHeight);
          
          // Connection line
          final lineColor = _getEventColorHex(actionType);
          svg.writeln('  <line x1="$startX" y1="$startY" x2="$endX" y2="$endY" stroke="$lineColor" stroke-width="3"/>');
          
          // End point (red X)
          svg.writeln('  <rect x="${endX - 8}" y="${endY - 8}" width="16" height="16" fill="#FF0000"/>');
          svg.writeln('  <text x="$endX" y="${endY + 3}" text-anchor="middle" fill="white" font-size="10" font-weight="bold">X</text>');
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
          // Court content
          pw.Expanded(
            child: pw.Stack(
              children: [
                // Court outline (inner court with 10ft zones around it)
                // Inner court: left=100, top=100, width=400, height=300, bottom=400 (RECTANGLE)
                pw.Positioned(
                  left: 100, // 100px margin from left (10ft zone)
                  top: 100, // 100px margin from top (10ft zone)
                  child: pw.Container(
                    width: 400, // Inner court width (sideline to sideline)
                    height: 300, // Inner court height (endline to endline)
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue, width: 2),
                    ),
                  ),
                ),
                // Net line (center of inner court, horizontal from sideline to sideline)
                // Net: left=100, top=250 (center), width=400, height=3 (sideline to sideline)
                pw.Positioned(
                  left: 100, // Start at left sideline
                  top: 250, // Center of inner court (100 + 300/2)
                  child: pw.Container(
                    width: 400, // Full width from sideline to sideline
                    height: 3, // Net height
                    decoration: pw.BoxDecoration(color: PdfColors.purple),
                  ),
                ),
                // 10-foot lines (extend horizontally from sideline to sideline, 60px from net)
                // Left 10-ft: left=100, top=190 (250-60), width=400, height=2 (sideline to sideline)
                pw.Positioned(
                  left: 100, // Start at left sideline
                  top: 190, // 60 pixels from net center (250 - 60)
                  child: pw.Container(
                    width: 400, // Full width from sideline to sideline
                    height: 2, // Line height
                    decoration: pw.BoxDecoration(color: PdfColors.grey),
                  ),
                ),
                // Right 10-ft: left=100, top=310 (250+60), width=400, height=2 (sideline to sideline)
                pw.Positioned(
                  left: 100, // Start at left sideline
                  top: 310, // 60 pixels from net center (250 + 60)
                  child: pw.Container(
                    width: 400, // Full width from sideline to sideline
                    height: 2, // Line height
                    decoration: pw.BoxDecoration(color: PdfColors.grey),
                  ),
                ),
                // Connection lines between start and end points
                ...events.map((event) {
                  if (event.fromX != null &&
                      event.fromY != null &&
                      event.toX != null &&
                      event.toY != null) {
                    // Map coordinates to inner court area (0,0 = top-left of inner court)
                    final innerCourtLeft = 100.0; // Inner court left position
                    final innerCourtTop = 100.0; // Inner court top position
                    final innerCourtWidth = 400.0; // Inner court width
                    final innerCourtHeight =
                        300.0; // Inner court height (endline to endline)

                    // Map coordinates (0,0) to top-left of inner court
                    final startX =
                        innerCourtLeft + (event.fromX! * innerCourtWidth);
                    final startY =
                        innerCourtTop + (event.fromY! * innerCourtHeight);
                    final endX =
                        innerCourtLeft + (event.toX! * innerCourtWidth);
                    final endY =
                        innerCourtTop + (event.toY! * innerCourtHeight);

                    // Calculate line properties
                    final dx = endX - startX;
                    final dy = endY - startY;

                    // Create solid diagonal lines using overlapping segments
                    final segments = 50; // More segments for solid line effect
                    final segmentDx = dx / segments;
                    final segmentDy = dy / segments;

                    // Create overlapping positioned containers for solid line effect
                    return pw.Stack(
                      children: List.generate(segments, (i) {
                        final segmentStartX = startX + (i * segmentDx);
                        final segmentStartY = startY + (i * segmentDy);

                        return pw.Positioned(
                          left: segmentStartX - 1,
                          top: segmentStartY - 1,
                          child: pw.Container(
                            width: 4,
                            height: 4,
                            decoration: pw.BoxDecoration(
                              color: _getEventColor(actionType),
                            ),
                          ),
                        );
                      }),
                    );
                  }
                  return pw.Container(); // Empty container for events without both coordinates
                }).toList(),
                // Start points (green circles) - rendered after connection lines
                ...events.map((event) {
                  if (event.fromX != null && event.fromY != null) {
                    // Map coordinates to inner court area (0,0 = top-left of inner court)
                    final innerCourtLeft = 100.0; // Inner court left position
                    final innerCourtTop = 100.0; // Inner court top position
                    final innerCourtWidth = 400.0; // Inner court width
                    final innerCourtHeight =
                        300.0; // Inner court height (endline to endline)

                    final x = innerCourtLeft + (event.fromX! * innerCourtWidth);
                    final y = innerCourtTop + (event.fromY! * innerCourtHeight);

                    return pw.Positioned(
                      left: x - 8,
                      top: y - 8,
                      child: pw.Container(
                        width: 16,
                        height: 16,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green,
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(
                            color: PdfColors.black,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }
                  return pw.Container(); // Empty container for events without coordinates
                }).toList(),
                // End points (red X) - rendered last to be on top
                ...events.map((event) {
                  if (event.toX != null && event.toY != null) {
                    // Map coordinates to inner court area (0,0 = top-left of inner court)
                    final innerCourtLeft = 100.0; // Inner court left position
                    final innerCourtTop = 100.0; // Inner court top position
                    final innerCourtWidth = 400.0; // Inner court width
                    final innerCourtHeight =
                        300.0; // Inner court height (endline to endline)

                    final x = innerCourtLeft + (event.toX! * innerCourtWidth);
                    final y = innerCourtTop + (event.toY! * innerCourtHeight);

                    return pw.Positioned(
                      left: x - 8,
                      top: y - 8,
                      child: pw.Container(
                        width: 16,
                        height: 16,
                        decoration: pw.BoxDecoration(color: PdfColors.red),
                        child: pw.Center(
                          child: pw.Text(
                            'X',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return pw.Container(); // Empty container for events without end coordinates
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _getEventColor(EventType actionType) {
    switch (actionType) {
      case EventType.serve:
        return PdfColors.cyan;
      case EventType.pass:
        return PdfColors.green;
      case EventType.attack:
        return PdfColors.orange;
      case EventType.block:
        return PdfColors.purple;
      case EventType.dig:
        return PdfColors.red;
      case EventType.set:
        return PdfColors.yellow;
      case EventType.freeball:
        return PdfColors.lime;
    }
  }

  static String _formatHitPercentage(double hitPercentage) {
    if (hitPercentage >= 1.0) {
      return '1.000';
    } else {
      return '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';
    }
  }
}
