import 'package:flutter/material.dart';
import 'stat_button.dart';
import 'serve_toggle_button.dart';

class StatsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLoading;
  final List<Widget> children;

  const StatsSection({
    super.key,
    required this.title,
    this.subtitle,
    this.isLoading = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: isLoading
                      ? _buildLoadingIndicator()
                      : _buildSubtitle(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Loading...',
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    if (subtitle == null) return const SizedBox.shrink();

    // Check if this is passing stats with values to bold
    if (subtitle!.contains('Ace:') &&
        subtitle!.contains('1:') &&
        subtitle!.contains('2:')) {
      return _buildPassingStatsSubtitle();
    }

    return Text(
      subtitle!,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPassingStatsSubtitle() {
    final parts = subtitle!.split(' | ');
    final baseStyle = TextStyle(
      fontSize: 14,
      color: Colors.grey[600],
      fontWeight: FontWeight.w500,
    );
    final boldStyle = TextStyle(
      fontSize: 14,
      color: Colors.grey[600],
      fontWeight: FontWeight.bold,
    );

    List<TextSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];

      if (i > 0) {
        spans.add(TextSpan(text: ' | ', style: baseStyle));
      }

      if (part.contains('Ace:') ||
          part.contains('1:') ||
          part.contains('2:') ||
          part.contains('3:') ||
          part.contains('0:')) {
        final colonIndex = part.indexOf(':');
        if (colonIndex != -1) {
          final label = part.substring(0, colonIndex + 1);
          final value = part.substring(colonIndex + 1);
          spans.add(TextSpan(text: label, style: baseStyle));
          spans.add(TextSpan(text: value, style: boldStyle));
        } else {
          spans.add(TextSpan(text: part, style: baseStyle));
        }
      } else {
        spans.add(TextSpan(text: part, style: baseStyle));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class StatButtonRow extends StatelessWidget {
  final List<StatButtonData> buttons;

  const StatButtonRow({super.key, required this.buttons});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: buttons
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final button = entry.value;

            return [
              StatButton(
                label: button.label,
                color: button.color,
                onPressed: button.onPressed,
                isDisabled: button.isDisabled,
              ),
              if (index < buttons.length - 1) const SizedBox(width: 4),
            ];
          })
          .expand((widgets) => widgets)
          .toList(),
    );
  }
}

class StatButtonData {
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isDisabled;

  StatButtonData({
    required this.label,
    required this.color,
    this.onPressed,
    this.isDisabled = false,
  });
}

class ServeToggleRow extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String> onChanged;
  final bool isDisabled;

  const ServeToggleRow({
    super.key,
    this.selectedValue,
    required this.onChanged,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ServeToggleButton(
          label: 'Float',
          value: 'float',
          selectedValue: selectedValue,
          onChanged: isDisabled ? (_) {} : onChanged,
        ),
        const SizedBox(width: 4),
        ServeToggleButton(
          label: 'Hybrid',
          value: 'hybrid',
          selectedValue: selectedValue,
          onChanged: isDisabled ? (_) {} : onChanged,
        ),
        const SizedBox(width: 4),
        ServeToggleButton(
          label: 'Spin',
          value: 'spin',
          selectedValue: selectedValue,
          onChanged: isDisabled ? (_) {} : onChanged,
        ),
      ],
    );
  }
}
