import 'package:flutter/material.dart';

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
  });

  @override
  State<VolleyballCourt> createState() => _VolleyballCourtState();
}

class _VolleyballCourtState extends State<VolleyballCourt> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      if (widget.onCourtTap != null && widget.isRecording) {
                        final RenderBox renderBox =
                            context.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.globalPosition,
                        );

                        // Convert to court coordinates in feet
                        // Inner court is 480x240 pixels, positioned at (90, 45) within outer border
                        // Court is 60 feet wide (X) and 30 feet tall (Y)
                        // Net is at X=60 feet (right side of court)
                        // Top left of inner court is (0,0), bottom left is (0,30)
                        // Areas outside court can have negative coordinates
                        final courtOffsetX = (660.0 - 480.0) / 2; // 90 pixels
                        final courtOffsetY = (330.0 - 240.0) / 2; // 45 pixels
                        final x =
                            ((localPosition.dx - courtOffsetX) / 480.0) *
                            60.0; // 480 pixels = 60 feet
                        final y =
                            ((localPosition.dy - courtOffsetY) / 240.0) *
                            30.0; // 240 pixels = 30 feet

                        widget.onCourtTap!(x, y);
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
                                'Start: (${widget.startX?.toStringAsFixed(1) ?? '?'}ft, ${widget.startY?.toStringAsFixed(1) ?? '?'}ft)',
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
                                'End: (${widget.endX?.toStringAsFixed(1) ?? '?'}ft, ${widget.endY?.toStringAsFixed(1) ?? '?'}ft)',
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

  VolleyballCourtPainter({
    this.startX,
    this.startY,
    this.endX,
    this.endY,
    this.hasStartPoint = false,
    this.isRecording = false,
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

    // Draw coordinate points if recording
    if (isRecording) {
      // Draw start point if available
      if (hasStartPoint && startX != null && startY != null) {
        final courtOffsetX = (size.width - 480) / 2; // 90 pixels
        final courtOffsetY = (size.height - 240) / 2; // 45 pixels
        final startXPos =
            courtOffsetX +
            (startX! / 60.0) * 480; // Convert feet to pixels within inner court
        final startYPos =
            courtOffsetY +
            (startY! / 30.0) * 240; // Convert feet to pixels within inner court

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
            courtOffsetX +
            (endX! / 60.0) * 480; // Convert feet to pixels within inner court
        final endYPos =
            courtOffsetY +
            (endY! / 30.0) * 240; // Convert feet to pixels within inner court

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
        if (hasStartPoint && startX != null && startY != null) {
          final courtOffsetX = (size.width - 480) / 2; // 90 pixels
          final courtOffsetY = (size.height - 240) / 2; // 45 pixels
          final startXPos =
              courtOffsetX +
              (startX! / 60.0) *
                  480; // Convert feet to pixels within inner court
          final startYPos =
              courtOffsetY +
              (startY! / 30.0) *
                  240; // Convert feet to pixels within inner court

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is VolleyballCourtPainter &&
        (oldDelegate.startX != startX ||
            oldDelegate.startY != startY ||
            oldDelegate.endX != endX ||
            oldDelegate.endY != endY ||
            oldDelegate.hasStartPoint != hasStartPoint ||
            oldDelegate.isRecording != isRecording);
  }
}
