import 'package:flutter/material.dart';

class VolleyballCourt extends StatefulWidget {
  final Function(double x, double y)? onCourtTap;
  final double? selectedX;
  final double? selectedY;
  final String? selectedAction;
  final bool isRecording;

  const VolleyballCourt({
    super.key,
    this.onCourtTap,
    this.selectedX,
    this.selectedY,
    this.selectedAction,
    this.isRecording = false,
  });

  @override
  State<VolleyballCourt> createState() => _VolleyballCourtState();
}

class _VolleyballCourtState extends State<VolleyballCourt> {
  double? _tempX;
  double? _tempY;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.selectedAction != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF)),
              ),
              child: Text(
                'Recording: ${widget.selectedAction}',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00E5FF), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GestureDetector(
                onTapDown: (details) {
                  if (widget.onCourtTap != null && widget.isRecording) {
                    final RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    final localPosition = renderBox.globalToLocal(
                      details.globalPosition,
                    );

                    // Convert to court coordinates (0-480 for X, 0-240 for Y)
                    // Calculate court position within the widget
                    final courtOffsetX = (renderBox.size.width - 480) / 2;
                    final courtOffsetY = (renderBox.size.height - 240) / 2;

                    // Convert to court coordinates (0-480 range for X, 0-240 range for Y)
                    final x = ((localPosition.dx - courtOffsetX) / 480 * 480)
                        .clamp(0.0, 480.0);
                    final y = ((localPosition.dy - courtOffsetY) / 240 * 240)
                        .clamp(0.0, 240.0);

                    setState(() {
                      _tempX = x;
                      _tempY = y;
                    });

                    widget.onCourtTap!(x, y);
                  }
                },
                child: CustomPaint(
                  size: const Size(
                    660,
                    330,
                  ), // Horizontal court with 330x330 square halves
                  painter: VolleyballCourtPainter(
                    selectedX: widget.selectedX ?? _tempX,
                    selectedY: widget.selectedY ?? _tempY,
                    isRecording: widget.isRecording,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if ((widget.selectedX != null || _tempX != null) &&
              (widget.selectedY != null || _tempY != null))
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00FF88)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCoordinateDisplay(
                    'X',
                    widget.selectedX ?? _tempX!,
                    const Color(0xFF00E5FF),
                  ),
                  _buildCoordinateDisplay(
                    'Y',
                    widget.selectedY ?? _tempY!,
                    const Color(0xFF00FF88),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinateDisplay(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class VolleyballCourtPainter extends CustomPainter {
  final double? selectedX;
  final double? selectedY;
  final bool isRecording;

  VolleyballCourtPainter({
    this.selectedX,
    this.selectedY,
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

    // Draw selected position if recording
    if (isRecording && selectedX != null && selectedY != null) {
      // Convert coordinates to court position
      final x = courtOffsetX + (selectedX! / 480) * courtSize;
      final y = courtOffsetY + (selectedY! / 240) * courtHeight;

      // Draw position marker
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()
          ..color = const Color(0xFFFF6B6B)
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(
        Offset(x, y),
        12,
        Paint()
          ..color = const Color(0xFFFF6B6B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is VolleyballCourtPainter &&
        (oldDelegate.selectedX != selectedX ||
            oldDelegate.selectedY != selectedY ||
            oldDelegate.isRecording != isRecording);
  }
}
