import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/practice.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../utils/date_utils.dart';
import 's3_service.dart';
import 'email_service.dart';

class PdfService {
  static Future<String> generatePracticeAnalysisPDF({
    required Practice practice,
    required List<Player> practicePlayers,
    required List<Event> teamEvents,
    required Map<String, dynamic> Function(Player) getPlayerServingStats,
    required Map<String, dynamic> Function(Player) getPlayerPassingStats,
    required Map<String, dynamic> Function(Player) getPlayerAttackingStats,
    required Map<String, int> Function(Player) getPlayerBlockingStats,
    required Map<String, int> Function(Player) getPlayerDigStats,
    required Map<String, int> Function(Player) getPlayerSetStats,
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
            getPlayerBlockingStats,
            getPlayerDigStats,
            getPlayerSetStats,
          ),
        ],
      ),
    );

    // Add Team Statistics Page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              'Team Statistics',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildTeamStatsCharts(
            practicePlayers,
            teamEvents,
            getPlayerServingStats,
            getPlayerPassingStats,
            getPlayerAttackingStats,
          ),
        ],
      ),
    );

    // Add individual pages for each player with all their actions
    for (final player in practicePlayers) {
      final playerEvents = teamEvents
          .where((e) => e.player.id == player.id)
          .toList();

      if (playerEvents.isNotEmpty) {
        // Group events by action type
        final eventsByAction = <EventType, List<Event>>{};
        for (final event in playerEvents) {
          eventsByAction.putIfAbsent(event.type, () => []).add(event);
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Player header
                  pw.Text(
                    '${player.fullName} - Complete Analysis',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Jersey #${player.jerseyNumber ?? 'N/A'} | ${playerEvents.length} total events',
                    style: pw.TextStyle(fontSize: 14),
                  ),
                  pw.SizedBox(height: 16),

                  // Player stats summary
                  _buildPlayerStatsSummary(
                    player,
                    getPlayerServingStats,
                    getPlayerPassingStats,
                    getPlayerAttackingStats,
                  ),
                  pw.SizedBox(height: 20),

                  // Court visualizations for each action type
                  pw.Expanded(
                    child: pw.Row(
                      children: [
                        // Left column - courts
                        pw.Expanded(
                          flex: 2,
                          child: pw.Column(
                            children: [
                              pw.Text(
                                'Court Visualizations',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 10),
                              pw.Expanded(
                                child: _buildPlayerCourtsGrid(eventsByAction),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        // Right column - detailed stats
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Detailed Statistics',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 10),
                              pw.Expanded(
                                child: _buildPlayerDetailedStats(
                                  player,
                                  eventsByAction,
                                  getPlayerServingStats,
                                  getPlayerPassingStats,
                                  getPlayerAttackingStats,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
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

    // Upload to S3
    print('=== ABOUT TO UPLOAD TO S3 ===');
    try {
      final generationTime = DateTime.now();
      print(
        'Calling S3Service.uploadPDF with practice: ${practice.practiceTitle}',
      );
      final s3Url = await S3Service.uploadPDF(
        pdfFile: file,
        practiceName: practice.practiceTitle,
        generationTime: generationTime,
      );

      print('=== PDF UPLOADED TO S3 ===');
      print('S3 URL: $s3Url');
      print('=========================');

      // Send email with PDF attachment
      try {
        print('=== SENDING EMAIL ===');
        final emailSent = await EmailService.sendPDF(
          pdfFile: file,
          practiceName: practice.practiceTitle,
          practiceDate: practice.date,
        );

        if (emailSent) {
          print('✅ Email sent successfully');
        } else {
          print('❌ Email failed to send');
        }
        print('=====================');
      } catch (e) {
        print('=== EMAIL SEND FAILED ===');
        print('Error: $e');
        print('Continuing without email...');
        print('=========================');
        // Don't throw error - continue without email
      }
    } catch (e) {
      print('=== S3 UPLOAD FAILED ===');
      print('Error: $e');
      print('Continuing with local file save...');
      print('=========================');
      // Don't throw error - continue with local file
    }

    return filePath;
  }

  static pw.Widget _buildPlayerStatsTable(
    List<Player> players,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
    Map<String, dynamic> Function(Player) getPlayerAttackingStats,
    Map<String, int> Function(Player) getPlayerBlockingStats,
    Map<String, int> Function(Player) getPlayerDigStats,
    Map<String, int> Function(Player) getPlayerSetStats,
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
      'B.Solo',
      'B.Assist',
      'B.Error',
      'D.Over',
      'D.Plat',
      'S.InSys',
      'S.OutSys',
    ];

    return pw.Table.fromTextArray(
      headers: tableHeaders,
      data: players.map((player) {
        final servingStats = getPlayerServingStats(player);
        final passingStats = getPlayerPassingStats(player);
        final attackingStats = getPlayerAttackingStats(player);
        final blockingStats = getPlayerBlockingStats(player);
        final digStats = getPlayerDigStats(player);
        final setStats = getPlayerSetStats(player);

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
          (blockingStats['solo'] ?? 0).toString(),
          (blockingStats['assist'] ?? 0).toString(),
          (blockingStats['error'] ?? 0).toString(),
          (digStats['overhand'] ?? 0).toString(),
          (digStats['platform'] ?? 0).toString(),
          (setStats['in_system'] ?? 0).toString(),
          (setStats['out_of_system'] ?? 0).toString(),
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

  static String _formatPassingAverage(double average) {
    if (average >= 3.0) return '3.000';
    return average.toStringAsFixed(3);
  }

  static pw.Widget _buildPlayerStatsSummary(
    Player player,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
    Map<String, dynamic> Function(Player) getPlayerAttackingStats,
  ) {
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

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          // Serving stats
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SERVING',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.Text('Aces: ${servingStats['ace'] ?? 0}'),
              pw.Text('In: ${servingStats['in'] ?? 0}'),
              pw.Text('Errors: ${servingStats['error'] ?? 0}'),
              pw.Text('Total: ${servingStats['total'] ?? 0}'),
            ],
          ),
          // Passing stats
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PASSING',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green,
                ),
              ),
              pw.Text('Aces: ${passingStats['ace'] ?? 0}'),
              pw.Text('3s: ${passingStats['3'] ?? 0}'),
              pw.Text('2s: ${passingStats['2'] ?? 0}'),
              pw.Text('1s: ${passingStats['1'] ?? 0}'),
              pw.Text('0s: ${passingStats['0'] ?? 0}'),
              pw.Text(
                'Avg: ${_formatPassingAverage(passingStats['average'] as double? ?? 0.0)}',
              ),
            ],
          ),
          // Attacking stats
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ATTACKING',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange,
                ),
              ),
              pw.Text('Kills: $kills'),
              pw.Text('In: ${attackingStats['in'] ?? 0}'),
              pw.Text('Errors: $errors'),
              pw.Text('Total: $totalAttacks'),
              pw.Text('Hit %: ${_formatHitPercentage(hitPercentage)}'),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPlayerCourtsGrid(
    Map<EventType, List<Event>> eventsByAction,
  ) {
    final actionTypes = EventType.values
        .where(
          (actionType) =>
              eventsByAction.containsKey(actionType) &&
              eventsByAction[actionType]!.isNotEmpty,
        )
        .toList();

    if (actionTypes.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'No events recorded',
          style: pw.TextStyle(fontSize: 14, color: PdfColors.grey),
        ),
      );
    }

    // Create a grid of courts - 2 columns max
    final rows = <pw.Widget>[];
    for (int i = 0; i < actionTypes.length; i += 2) {
      final rowActions = <EventType>[];
      if (i < actionTypes.length) rowActions.add(actionTypes[i]);
      if (i + 1 < actionTypes.length) rowActions.add(actionTypes[i + 1]);

      rows.add(
        pw.Row(
          children: rowActions.map((actionType) {
            final events = eventsByAction[actionType]!;
            return pw.Expanded(
              child: pw.Column(
                children: [
                  pw.Text(
                    actionType.displayName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _getEventColorPdf(actionType),
                    ),
                  ),
                  pw.Text(
                    '${events.length} events',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 8),
                  pw.SizedBox(
                    width: 280,
                    height: 200,
                    child: _buildCourtVisualization(events, actionType),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );

      if (i + 2 < actionTypes.length) {
        rows.add(pw.SizedBox(height: 16));
      }
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _buildPlayerDetailedStats(
    Player player,
    Map<EventType, List<Event>> eventsByAction,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
    Map<String, dynamic> Function(Player) getPlayerAttackingStats,
  ) {
    final statsWidgets = <pw.Widget>[];

    for (final actionType in EventType.values) {
      if (eventsByAction.containsKey(actionType) &&
          eventsByAction[actionType]!.isNotEmpty) {
        final events = eventsByAction[actionType]!;

        statsWidgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _getEventColorPdf(actionType)),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  actionType.displayName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _getEventColorPdf(actionType),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Events: ${events.length}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                // Add specific stats based on action type
                ..._buildActionSpecificStats(
                  actionType,
                  player,
                  events,
                  getPlayerServingStats,
                  getPlayerPassingStats,
                  getPlayerAttackingStats,
                ),
              ],
            ),
          ),
        );
      }
    }

    if (statsWidgets.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'No detailed stats available',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
        ),
      );
    }

    return pw.Column(children: statsWidgets);
  }

  static List<pw.Widget> _buildActionSpecificStats(
    EventType actionType,
    Player player,
    List<Event> events,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
    Map<String, dynamic> Function(Player) getPlayerAttackingStats,
  ) {
    switch (actionType) {
      case EventType.serve:
        final stats = getPlayerServingStats(player);
        return [
          pw.Text(
            'Aces: ${stats['ace'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'In: ${stats['in'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            'Errors: ${stats['error'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ];
      case EventType.pass:
        final stats = getPlayerPassingStats(player);
        return [
          pw.Text(
            'Aces: ${stats['ace'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '3s: ${stats['3'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '2s: ${stats['2'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '1s: ${stats['1'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '0s: ${stats['0'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ];
      case EventType.attack:
        final stats = getPlayerAttackingStats(player);
        final total =
            (stats['kill'] ?? 0) + (stats['in'] ?? 0) + (stats['error'] ?? 0);
        final kills = stats['kill'] ?? 0;
        final errors = stats['error'] ?? 0;
        final hitPercentage = total > 0 ? (kills - errors) / total : 0.0;
        return [
          pw.Text('Kills: $kills', style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'In: ${stats['in'] ?? 0}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text('Errors: $errors', style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'Hit %: ${_formatHitPercentage(hitPercentage)}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ];
      default:
        return [
          pw.Text(
            '${events.length} events recorded',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ];
    }
  }

  static PdfColor _getEventColorPdf(EventType actionType) {
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

  static pw.Widget _buildTeamStatsCharts(
    List<Player> practicePlayers,
    List<Event> teamEvents,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
    Map<String, dynamic> Function(Player) getPlayerAttackingStats,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Team Highlights Section
        pw.Text(
          'Team Highlights',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        _buildTeamHighlights(
          practicePlayers,
          teamEvents,
          getPlayerServingStats,
          getPlayerPassingStats,
          getPlayerAttackingStats,
        ),
        pw.SizedBox(height: 30),

        // Charts Section
        pw.Text(
          'Team Performance Charts',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 15),

        // Row of charts
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Passing Chart
            pw.Expanded(
              child: _buildPassingChart(
                practicePlayers,
                teamEvents,
                getPlayerPassingStats,
              ),
            ),
            pw.SizedBox(width: 15),
            // Serving Chart
            pw.Expanded(
              child: _buildServingChart(
                practicePlayers,
                teamEvents,
                getPlayerServingStats,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTeamHighlights(
    List<Player> practicePlayers,
    List<Event> teamEvents,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
    Map<String, dynamic> Function(Player) getPlayerAttackingStats,
  ) {
    // Calculate team totals from raw data
    int totalServes = 0;
    int totalAces = 0;
    int totalServeErrors = 0;
    int totalServeIn = 0;
    int totalPasses = 0;
    int totalPassingPoints = 0;
    int totalAttacks = 0;
    int totalKills = 0;
    int totalErrors = 0;

    for (final player in practicePlayers) {
      final servingStats = getPlayerServingStats(player);
      final passingStats = getPlayerPassingStats(player);
      final attackingStats = getPlayerAttackingStats(player);

      totalServes += (servingStats['total'] ?? 0) as int;
      totalAces += (servingStats['ace'] ?? 0) as int;
      totalServeErrors += (servingStats['error'] ?? 0) as int;
      totalServeIn += (servingStats['in'] ?? 0) as int;

      // Calculate passing points from individual ratings
      totalPasses += (passingStats['total'] ?? 0) as int;
      totalPassingPoints +=
          ((passingStats['ace'] ?? 0) as int) * 3; // Ace = 3 points
      totalPassingPoints +=
          ((passingStats['3'] ?? 0) as int) * 3; // 3 = 3 points
      totalPassingPoints +=
          ((passingStats['2'] ?? 0) as int) * 2; // 2 = 2 points
      totalPassingPoints +=
          ((passingStats['1'] ?? 0) as int) * 1; // 1 = 1 point
      totalPassingPoints +=
          ((passingStats['0'] ?? 0) as int) * 0; // 0 = 0 points

      totalAttacks += (attackingStats['total'] ?? 0) as int;
      totalKills += (attackingStats['kill'] ?? 0) as int;
      totalErrors += (attackingStats['error'] ?? 0) as int;
    }

    // Calculate correct percentages
    // For serving %, only count serves with results (in + ace + error)
    final servesWithResults = totalServeIn + totalAces + totalServeErrors;
    final servingPercentage = servesWithResults > 0
        ? (totalServeIn + totalAces) / servesWithResults
        : 0.0;
    final passingAverage = totalPasses > 0
        ? totalPassingPoints / totalPasses
        : 0.0;
    final hitPercentage = totalAttacks > 0
        ? (totalKills - totalErrors) / totalAttacks
        : 0.0;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        _buildHighlightCard(
          'Total Serves',
          totalServes.toString(),
          '${(servingPercentage * 100).toStringAsFixed(1)}% In',
        ),
        _buildHighlightCard(
          'Total Passes',
          totalPasses.toString(),
          'Avg: ${passingAverage.toStringAsFixed(2)}',
        ),
        _buildHighlightCard(
          'Total Attacks',
          totalAttacks.toString(),
          'Hit %: ${_formatHitPercentage(hitPercentage)}',
        ),
        _buildHighlightCard(
          'Total Aces',
          totalAces.toString(),
          'Errors: $totalServeErrors',
        ),
      ],
    );
  }

  static pw.Widget _buildHighlightCard(
    String title,
    String value,
    String subtitle,
  ) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            subtitle,
            style: pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPassingChart(
    List<Player> practicePlayers,
    List<Event> teamEvents,
    Map<String, dynamic> Function(Player) getPlayerPassingStats,
  ) {
    // Calculate total passing ratings
    final totalRatings = <String, int>{
      'ace': 0,
      '0': 0,
      '1': 0,
      '2': 0,
      '3': 0,
    };

    for (final player in practicePlayers) {
      final passingStats = getPlayerPassingStats(player);
      for (final rating in totalRatings.keys) {
        totalRatings[rating] =
            (totalRatings[rating] ?? 0) + ((passingStats[rating] ?? 0) as int);
      }
    }

    final totalPasses = totalRatings.values.reduce((a, b) => a + b);
    if (totalPasses == 0) {
      return pw.Container(
        height: 200,
        child: pw.Center(child: pw.Text('No passing data available')),
      );
    }

    // Find the maximum count for proper scaling
    final maxCount = totalRatings.values.reduce((a, b) => a > b ? a : b);

    return pw.Container(
      height: 250,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Passing Distribution',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (final entry in totalRatings.entries)
                  pw.Expanded(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Container(
                          height: maxCount > 0
                              ? (entry.value / maxCount) * 150
                              : 0,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                          decoration: pw.BoxDecoration(
                            color: _getPassingRatingColor(entry.key),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          entry.key,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          entry.value.toString(),
                          style: pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildServingChart(
    List<Player> practicePlayers,
    List<Event> teamEvents,
    Map<String, dynamic> Function(Player) getPlayerServingStats,
  ) {
    // Calculate total serving types
    final servingTypes = <String, int>{'float': 0, 'hybrid': 0, 'spin': 0};

    for (final player in practicePlayers) {
      final servingStats = getPlayerServingStats(player);
      for (final type in servingTypes.keys) {
        final count = (servingStats[type] ?? 0) as int;
        servingTypes[type] = (servingTypes[type] ?? 0) + count;
      }
    }

    final totalServes = servingTypes.values.reduce((a, b) => a + b);
    if (totalServes == 0) {
      return pw.Container(
        height: 200,
        child: pw.Center(child: pw.Text('No serving data available')),
      );
    }

    // Find the maximum count for proper scaling
    final maxCount = servingTypes.values.reduce((a, b) => a > b ? a : b);

    return pw.Container(
      height: 250,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Serving Types',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (final entry in servingTypes.entries)
                  pw.Expanded(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Container(
                          height: maxCount > 0
                              ? (entry.value / maxCount) * 150
                              : 0,
                          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                          decoration: pw.BoxDecoration(
                            color: _getServingTypeColor(entry.key),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          entry.key.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          entry.value.toString(),
                          style: pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _getPassingRatingColor(String rating) {
    switch (rating) {
      case 'ace':
        return PdfColors.green;
      case '3':
        return PdfColors.green300;
      case '2':
        return PdfColors.orange;
      case '1':
        return PdfColors.orange300;
      case '0':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  static PdfColor _getServingTypeColor(String type) {
    switch (type) {
      case 'float':
        return PdfColors.blue;
      case 'hybrid':
        return PdfColors.purple;
      case 'spin':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }
}
