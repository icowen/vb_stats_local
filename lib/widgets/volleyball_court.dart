import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../providers/player_selection_provider.dart';

class VolleyballCourt extends StatefulWidget {
  final Function(double x, double y)? onCourtTap;
  final VoidCallback? onClear;
  final double? startX;
  final double? startY;
  final double? endX;
  final double? endY;
  final String? selectedAction;
  final bool isRecording;
  final bool hasStartPoint;
  final Map<String, int?>? courtZones;
  final Function(String)? onZoneTap;
  final Function(String)? onZoneLongPress;
  final List<Player>? teamPlayers;
  final String? selectedZone;

  const VolleyballCourt({
    super.key,
    this.onCourtTap,
    this.onClear,
    this.startX,
    this.startY,
    this.endX,
    this.endY,
    this.selectedAction,
    this.isRecording = false,
    this.hasStartPoint = false,
    this.courtZones,
    this.onZoneTap,
    this.onZoneLongPress,
    this.teamPlayers,
    this.selectedZone,
  });

  @override
  State<VolleyballCourt> createState() => _VolleyballCourtState();
}

class _VolleyballCourtState extends State<VolleyballCourt> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.isRecording
                    ? const Color(0xFF00FF88)
                    : const Color(0xFF00E5FF),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  GestureDetector(
                    onTapDown: (details) {
                      // Check if tap is on a zone first, but only handle zone assignment
                      // when we're specifically trying to assign a player to a zone
                      // (i.e., when only a player is selected and no action is selected)
                      final selectionProvider = context
                          .read<PlayerSelectionProvider>();
                      final selectedPlayer = selectionProvider.selectedPlayer;
                      final selectedActionType =
                          selectionProvider.selectedActionType;

                      // Only handle zone assignment when only a player is selected (no action)
                      final shouldHandleZoneAssignment =
                          selectedPlayer != null && selectedActionType == null;

                      if (shouldHandleZoneAssignment &&
                          (widget.onZoneTap != null ||
                              widget.onZoneLongPress != null) &&
                          widget.courtZones != null) {
                        final localPosition = details.localPosition;
                        final courtOffsetX = (660.0 - 480.0) / 2; // 90 pixels
                        final courtOffsetY = (330.0 - 240.0) / 2; // 45 pixels
                        final zoneWidth = 120.0; // 240/2 per side
                        final zoneHeight = 80.0; // 240/3 rows

                        // Check home side zones (left side)
                        for (int col = 0; col < 2; col++) {
                          for (int row = 0; row < 3; row++) {
                            final x = courtOffsetX + col * zoneWidth;
                            final y = courtOffsetY + row * zoneHeight;

                            if (localPosition.dx >= x &&
                                localPosition.dx <= x + zoneWidth &&
                                localPosition.dy >= y &&
                                localPosition.dy <= y + zoneHeight) {
                              final zoneKey = 'home_${col + row * 2 + 1}';
                              if (widget.onZoneTap != null) {
                                widget.onZoneTap!(zoneKey);
                              }
                              return; // Handle zone assignment - don't record coordinates
                            }
                          }
                        }

                        // Check away side zones (right side)
                        for (int col = 0; col < 2; col++) {
                          for (int row = 0; row < 3; row++) {
                            final x = courtOffsetX + 240 + col * zoneWidth;
                            final y = courtOffsetY + row * zoneHeight;

                            if (localPosition.dx >= x &&
                                localPosition.dx <= x + zoneWidth &&
                                localPosition.dy >= y &&
                                localPosition.dy <= y + zoneHeight) {
                              final zoneKey = 'away_${col + row * 2 + 1}';
                              if (widget.onZoneTap != null) {
                                widget.onZoneTap!(zoneKey);
                              }
                              return; // Handle zone assignment - don't record coordinates
                            }
                          }
                        }
                      }

                      // Handle court tap - always call onCourtTap if it exists
                      // The onCourtTap method will decide what to do based on current state
                      if (widget.onCourtTap != null) {
                        // Use the GestureDetector's local position directly
                        final localPosition = details.localPosition;

                        // Convert to normalized coordinates (0-1) within the court
                        // Use the same offset calculation as the painter
                        final courtOffsetX = (660.0 - 480.0) / 2; // 90 pixels
                        final courtOffsetY = (330.0 - 240.0) / 2; // 45 pixels
                        final x =
                            (localPosition.dx - courtOffsetX) /
                            480.0; // 0-1 normalized
                        final y =
                            (localPosition.dy - courtOffsetY) /
                            240.0; // 0-1 normalized

                        widget.onCourtTap!(x, y);
                      }
                    },
                    onTapUp: (details) {
                      // Handle zone tap
                      if (widget.onZoneTap != null &&
                          widget.courtZones != null) {
                        final localPosition = details.localPosition;
                        final courtOffsetX = (660.0 - 480.0) / 2; // 90 pixels
                        final courtOffsetY = (330.0 - 240.0) / 2; // 45 pixels
                        final zoneWidth = 120.0; // 240/2 per side
                        final zoneHeight = 80.0; // 240/3 rows

                        // Check home side zones (left side)
                        for (int col = 0; col < 2; col++) {
                          for (int row = 0; row < 3; row++) {
                            final zoneNum = col * 3 + row + 1;
                            final zoneKey = 'home_$zoneNum';
                            final x = courtOffsetX + col * zoneWidth;
                            final y = courtOffsetY + row * zoneHeight;

                            if (localPosition.dx >= x &&
                                localPosition.dx <= x + zoneWidth &&
                                localPosition.dy >= y &&
                                localPosition.dy <= y + zoneHeight) {
                              widget.onZoneTap!(zoneKey);
                              return;
                            }
                          }
                        }

                        // Check away side zones (right side)
                        for (int col = 0; col < 2; col++) {
                          for (int row = 0; row < 3; row++) {
                            final zoneNum = col * 3 + row + 1;
                            final zoneKey = 'away_$zoneNum';
                            final x = courtOffsetX + 240 + col * zoneWidth;
                            final y = courtOffsetY + row * zoneHeight;

                            if (localPosition.dx >= x &&
                                localPosition.dx <= x + zoneWidth &&
                                localPosition.dy >= y &&
                                localPosition.dy <= y + zoneHeight) {
                              widget.onZoneTap!(zoneKey);
                              return;
                            }
                          }
                        }
                      }
                    },
                    onLongPressStart: (details) {
                      // Handle zone long press for clearing zones
                      if (widget.onZoneLongPress != null &&
                          widget.courtZones != null) {
                        final localPosition = details.localPosition;
                        final courtOffsetX = (660.0 - 480.0) / 2; // 90 pixels
                        final courtOffsetY = (330.0 - 240.0) / 2; // 45 pixels
                        final zoneWidth = 120.0; // 240/2 per side
                        final zoneHeight = 80.0; // 240/3 rows

                        // Check home side zones (left side)
                        for (int col = 0; col < 2; col++) {
                          for (int row = 0; row < 3; row++) {
                            final zoneNum = col * 3 + row + 1;
                            final zoneKey = 'home_$zoneNum';
                            final x = courtOffsetX + col * zoneWidth;
                            final y = courtOffsetY + row * zoneHeight;

                            if (localPosition.dx >= x &&
                                localPosition.dx <= x + zoneWidth &&
                                localPosition.dy >= y &&
                                localPosition.dy <= y + zoneHeight) {
                              widget.onZoneLongPress!(zoneKey);
                              return;
                            }
                          }
                        }

                        // Check away side zones (right side)
                        for (int col = 0; col < 2; col++) {
                          for (int row = 0; row < 3; row++) {
                            final zoneNum = col * 3 + row + 1;
                            final zoneKey = 'away_$zoneNum';
                            final x = courtOffsetX + 240 + col * zoneWidth;
                            final y = courtOffsetY + row * zoneHeight;

                            if (localPosition.dx >= x &&
                                localPosition.dx <= x + zoneWidth &&
                                localPosition.dy >= y &&
                                localPosition.dy <= y + zoneHeight) {
                              widget.onZoneLongPress!(zoneKey);
                              return;
                            }
                          }
                        }
                      }
                    },
                    child: CustomPaint(
                      size: const Size(
                        660,
                        330,
                      ), // Horizontal court with 330x330 square halves
                      painter: VolleyballCourtPainter(
                        startX: widget.startX,
                        startY: widget.startY,
                        endX: widget.endX,
                        endY: widget.endY,
                        hasStartPoint: widget.hasStartPoint,
                        isRecording: widget.isRecording,
                        courtZones: widget.courtZones,
                        teamPlayers: widget.teamPlayers,
                        selectedZone: widget.selectedZone,
                      ),
                    ),
                  ),
                  // Clear button in top left
                  if (widget.isRecording &&
                      (widget.hasStartPoint || widget.endX != null))
                    Positioned(
                      top: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: widget.onClear,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red, width: 1),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Coordinates overlay in top right
                  if (widget.hasStartPoint || widget.endX != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF00FF88),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.hasStartPoint)
                              Text(
                                'Start: (${((widget.startX ?? 0) * 60).toStringAsFixed(1)}ft, ${((widget.startY ?? 0) * 30).toStringAsFixed(1)}ft)',
                                style: const TextStyle(
                                  color: Color(0xFF00FF88),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            if (widget.hasStartPoint && widget.endX != null)
                              const SizedBox(width: 8),
                            if (widget.endX != null)
                              Text(
                                'End: (${((widget.endX ?? 0) * 60).toStringAsFixed(1)}ft, ${((widget.endY ?? 0) * 30).toStringAsFixed(1)}ft)',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VolleyballCourtPainter extends CustomPainter {
  final double? startX;
  final double? startY;
  final double? endX;
  final double? endY;
  final bool hasStartPoint;
  final bool isRecording;
  final Map<String, int?>? courtZones;
  final List<Player>? teamPlayers;
  final String? selectedZone;

  VolleyballCourtPainter({
    this.startX,
    this.startY,
    this.endX,
    this.endY,
    this.hasStartPoint = false,
    this.isRecording = false,
    this.courtZones,
    this.teamPlayers,
    this.selectedZone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outerPaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.fill;

    final outerLinePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final courtLinePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final netPaint = Paint()
      ..color = const Color(0xFF9C27B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Draw outer border background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), outerPaint);

    // Draw outer border lines (sidelines and endlines)
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), outerLinePaint);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      outerLinePaint,
    );
    canvas.drawLine(Offset(0, 0), Offset(0, size.height), outerLinePaint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      outerLinePaint,
    );

    // Calculate court position (centered within outer border)
    // Outer border: 660x330, Court: 480x240 (two 240x240 halves)
    // Horizontal offset: (660-480)/2 = 90 (more room on endlines)
    // Vertical offset: (330-240)/2 = 45 (more room on sidelines)
    final courtOffsetX = (size.width - 480) / 2;
    final courtOffsetY = (size.height - 240) / 2;
    final courtSize = 480.0;
    final courtHeight = 240.0;

    // Draw court background (lighter color)
    canvas.drawRect(
      Rect.fromLTWH(courtOffsetX, courtOffsetY, courtSize, courtHeight),
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..style = PaintingStyle.fill,
    );

    // Draw court sidelines (top and bottom)
    canvas.drawLine(
      Offset(courtOffsetX, courtOffsetY),
      Offset(courtOffsetX + courtSize, courtOffsetY),
      courtLinePaint,
    );
    canvas.drawLine(
      Offset(courtOffsetX, courtOffsetY + courtHeight),
      Offset(courtOffsetX + courtSize, courtOffsetY + courtHeight),
      courtLinePaint,
    );

    // Draw court endlines (left and right)
    canvas.drawLine(
      Offset(courtOffsetX, courtOffsetY),
      Offset(courtOffsetX, courtOffsetY + courtHeight),
      courtLinePaint,
    );
    canvas.drawLine(
      Offset(courtOffsetX + courtSize, courtOffsetY),
      Offset(courtOffsetX + courtSize, courtOffsetY + courtHeight),
      courtLinePaint,
    );

    // Draw center line (net) - vertical line down the middle of the court
    final courtCenterX = courtOffsetX + courtSize / 2;
    canvas.drawLine(
      Offset(courtCenterX, courtOffsetY),
      Offset(courtCenterX, courtOffsetY + courtHeight),
      netPaint,
    );

    // Draw 10-foot attack lines (1/3 of the way from net to endline)
    // Each half is 240 pixels = 30 feet, so 10 feet = 80 pixels
    final attackLinePaint = Paint()
      ..color = const Color(0xFF666666)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Left attack line (10 feet from net on left side)
    final leftAttackLineX = courtCenterX - 80; // 80 pixels = 10 feet
    canvas.drawLine(
      Offset(leftAttackLineX, courtOffsetY - 5), // Extend past sidelines
      Offset(leftAttackLineX, courtOffsetY + courtHeight + 5),
      attackLinePaint,
    );

    // Right attack line (10 feet from net on right side)
    final rightAttackLineX = courtCenterX + 80; // 80 pixels = 10 feet
    canvas.drawLine(
      Offset(rightAttackLineX, courtOffsetY - 5), // Extend past sidelines
      Offset(rightAttackLineX, courtOffsetY + courtHeight + 5),
      attackLinePaint,
    );

    // Draw coordinate points if they exist
    if (startX != null || endX != null) {
      // Draw start point if available
      if (hasStartPoint && startX != null && startY != null) {
        final courtOffsetX = (size.width - 480) / 2; // 90 pixels
        final courtOffsetY = (size.height - 240) / 2; // 45 pixels
        final startXPos =
            courtOffsetX + (startX! * 480); // Convert normalized to pixels
        final startYPos =
            courtOffsetY + (startY! * 240); // Convert normalized to pixels

        // Draw start point (green)
        canvas.drawCircle(
          Offset(startXPos, startYPos),
          8,
          Paint()
            ..color = const Color(0xFF00FF88)
            ..style = PaintingStyle.fill,
        );

        canvas.drawCircle(
          Offset(startXPos, startYPos),
          12,
          Paint()
            ..color = const Color(0xFF00FF88)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }

      // Draw end point if available
      if (endX != null && endY != null) {
        final courtOffsetX = (size.width - 480) / 2; // 90 pixels
        final courtOffsetY = (size.height - 240) / 2; // 45 pixels
        final endXPos =
            courtOffsetX + (endX! * 480); // Convert normalized to pixels
        final endYPos =
            courtOffsetY + (endY! * 240); // Convert normalized to pixels

        // Draw end point (blue)
        canvas.drawCircle(
          Offset(endXPos, endYPos),
          8,
          Paint()
            ..color = const Color(0xFF00E5FF)
            ..style = PaintingStyle.fill,
        );

        canvas.drawCircle(
          Offset(endXPos, endYPos),
          12,
          Paint()
            ..color = const Color(0xFF00E5FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );

        // Draw line between start and end points
        if (hasStartPoint &&
            startX != null &&
            startY != null &&
            endX != null &&
            endY != null) {
          final courtOffsetX = (size.width - 480) / 2;
          final courtOffsetY = (size.height - 240) / 2;
          final startXPos =
              courtOffsetX + (startX! * 480); // Convert normalized to pixels
          final startYPos =
              courtOffsetY + (startY! * 240); // Convert normalized to pixels
          final endXPos =
              courtOffsetX + (endX! * 480); // Convert normalized to pixels
          final endYPos =
              courtOffsetY + (endY! * 240); // Convert normalized to pixels

          canvas.drawLine(
            Offset(startXPos, startYPos),
            Offset(endXPos, endYPos),
            Paint()
              ..color = const Color(0xFFFFFFFF)
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }

    // Draw court zones if courtZones is provided
    if (courtZones != null && teamPlayers != null) {
      _drawCourtZones(canvas, size, courtOffsetX, courtOffsetY);
    }
  }

  void _drawCourtZones(
    Canvas canvas,
    Size size,
    double courtOffsetX,
    double courtOffsetY,
  ) {
    // Zone dimensions
    final zoneWidth = 120.0; // 240/2 per side
    final zoneHeight = 80.0; // 240/3 rows

    // Zone border paint - only for internal boundaries
    final zoneBorderPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Home side zones (left side of court) - 2 columns × 3 rows
    for (int col = 0; col < 2; col++) {
      for (int row = 0; row < 3; row++) {
        final zoneNum = col * 3 + row + 1;
        final zoneKey = 'home_$zoneNum';
        final x = courtOffsetX + col * zoneWidth;
        final y = courtOffsetY + row * zoneHeight;

        // Draw selected zone background
        if (selectedZone == zoneKey) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, zoneWidth, zoneHeight),
            Paint()
              ..color = const Color(0xFFFFD700).withOpacity(0.2)
              ..style = PaintingStyle.fill,
          );
        }

        // Draw internal zone boundaries only (not the outer edges)
        // Top boundary (if not first row)
        if (row > 0) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x + zoneWidth, y),
            zoneBorderPaint,
          );
        }
        // Left boundary (if not first column)
        if (col > 0) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x, y + zoneHeight),
            zoneBorderPaint,
          );
        }

        // Draw zone number or player jersey
        if (courtZones![zoneKey] != null) {
          final player = teamPlayers!.firstWhere(
            (p) => p.id == courtZones![zoneKey],
            orElse: () => teamPlayers!.first,
          );
          final jerseyNumber = player.jerseyNumber?.toString() ?? '?';

          // Draw player circle
          canvas.drawCircle(
            Offset(x + zoneWidth / 2, y + zoneHeight / 2),
            12,
            Paint()
              ..color = const Color(0xFFFFD700)
              ..style = PaintingStyle.fill,
          );

          // Draw jersey number
          final textSpan = TextSpan(
            text: jerseyNumber,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              x + zoneWidth / 2 - textPainter.width / 2,
              y + zoneHeight / 2 - textPainter.height / 2,
            ),
          );
        } else {
          // Draw zone number
          final textSpan = TextSpan(
            text: '$zoneNum',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              x + zoneWidth / 2 - textPainter.width / 2,
              y + zoneHeight / 2 - textPainter.height / 2,
            ),
          );
        }
      }
    }

    // Away side zones (right side of court) - 2 columns × 3 rows
    for (int col = 0; col < 2; col++) {
      for (int row = 0; row < 3; row++) {
        final zoneNum = col * 3 + row + 1;
        final zoneKey = 'away_$zoneNum';
        final x =
            courtOffsetX + 240 + col * zoneWidth; // Start from center line
        final y = courtOffsetY + row * zoneHeight;

        // Draw selected zone background
        if (selectedZone == zoneKey) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, zoneWidth, zoneHeight),
            Paint()
              ..color = const Color(0xFFFFD700).withOpacity(0.2)
              ..style = PaintingStyle.fill,
          );
        }

        // Draw internal zone boundaries only (not the outer edges)
        // Top boundary (if not first row)
        if (row > 0) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x + zoneWidth, y),
            zoneBorderPaint,
          );
        }
        // Left boundary (if not first column)
        if (col > 0) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x, y + zoneHeight),
            zoneBorderPaint,
          );
        }

        // Draw zone number or player jersey
        if (courtZones![zoneKey] != null) {
          final player = teamPlayers!.firstWhere(
            (p) => p.id == courtZones![zoneKey],
            orElse: () => teamPlayers!.first,
          );
          final jerseyNumber = player.jerseyNumber?.toString() ?? '?';

          // Draw player circle
          canvas.drawCircle(
            Offset(x + zoneWidth / 2, y + zoneHeight / 2),
            12,
            Paint()
              ..color = const Color(0xFFFFD700)
              ..style = PaintingStyle.fill,
          );

          // Draw jersey number
          final textSpan = TextSpan(
            text: jerseyNumber,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              x + zoneWidth / 2 - textPainter.width / 2,
              y + zoneHeight / 2 - textPainter.height / 2,
            ),
          );
        } else {
          // Draw zone number
          final textSpan = TextSpan(
            text: '$zoneNum',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              x + zoneWidth / 2 - textPainter.width / 2,
              y + zoneHeight / 2 - textPainter.height / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is VolleyballCourtPainter &&
        (oldDelegate.startX != startX ||
            oldDelegate.startY != startY ||
            oldDelegate.endX != endX ||
            oldDelegate.endY != endY ||
            oldDelegate.hasStartPoint != hasStartPoint ||
            oldDelegate.isRecording != isRecording ||
            oldDelegate.courtZones != courtZones ||
            oldDelegate.selectedZone != selectedZone ||
            oldDelegate.teamPlayers != teamPlayers);
  }
}
