import 'package:flutter/material.dart';

class ServeToggleButton extends StatelessWidget {
  final String label;
  final String value;
  final String? selectedValue;
  final ValueChanged<String> onChanged;

  const ServeToggleButton({
    super.key,
    required this.label,
    required this.value,
    this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedValue == value;

    return Expanded(
      child: ElevatedButton(
        onPressed: () => onChanged(value),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? const Color(0xFF00E5FF)
              : Colors.grey[300],
          foregroundColor: isSelected ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
