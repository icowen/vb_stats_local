import 'package:flutter/material.dart';

class StatButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isDisabled;

  const StatButton({
    super.key,
    required this.label,
    required this.color,
    this.onPressed,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = isDisabled ? Colors.grey : color;

    return Expanded(
      child: OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: const Size(0, 24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: buttonColor,
          ),
        ),
      ),
    );
  }
}
