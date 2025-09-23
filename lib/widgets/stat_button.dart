import 'package:flutter/material.dart';

class StatButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isDisabled;
  final bool isSelected;

  const StatButton({
    super.key,
    required this.label,
    required this.color,
    this.onPressed,
    this.isDisabled = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = isDisabled ? Colors.grey : color;
    final backgroundColor = isSelected
        ? buttonColor.withOpacity(0.2)
        : Colors.transparent;
    final borderColor = isSelected ? buttonColor : buttonColor;
    final borderWidth = isSelected ? 2 : 1;

    return Expanded(
      child: OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: borderWidth.toDouble()),
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: const Size(0, 24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
            color: buttonColor,
          ),
        ),
      ),
    );
  }
}
