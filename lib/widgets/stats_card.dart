import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLoading;
  final List<Widget> children;

  const StatsCard({
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
}
