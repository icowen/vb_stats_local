import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../utils/app_colors.dart';

class PlayerStatsTable extends StatefulWidget {
  final Map<String, double> columnWidths;
  final List<Player> teamPlayers;
  final List<Event> teamEvents;
  final Function(List<Event>) getPlayerServingStats;
  final Function(List<Event>) getPlayerPassingStats;
  final Function(List<Event>) getPlayerAttackingStats;
  final Function(List<Event>) getPlayerBlockingStats;
  final Function(List<Event>) getPlayerDigStats;
  final Function(List<Event>) getPlayerSetStats;

  const PlayerStatsTable({
    super.key,
    required this.columnWidths,
    required this.teamPlayers,
    required this.teamEvents,
    required this.getPlayerServingStats,
    required this.getPlayerPassingStats,
    required this.getPlayerAttackingStats,
    required this.getPlayerBlockingStats,
    required this.getPlayerDigStats,
    required this.getPlayerSetStats,
  });

  @override
  State<PlayerStatsTable> createState() => _PlayerStatsTableState();
}

class _PlayerStatsTableState extends State<PlayerStatsTable> {
  late ScrollController _statsScrollController;

  String _formatHitPercentage(double hitPercentage) {
    if (hitPercentage >= 1.0) {
      return '1.000';
    } else {
      return '.${(hitPercentage * 1000).round().toString().padLeft(3, '0')}';
    }
  }

  @override
  void initState() {
    super.initState();
    _statsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _statsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          // Sticky Player Info Columns
          Container(
            width:
                widget.columnWidths['Player']! + widget.columnWidths['Jersey']!,
            child: _buildStickyPlayerInfoColumn(),
          ),
          // Vertical border between player info and stats
          Container(width: 1, color: Colors.grey),
          // Scrollable Stats Columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _statsScrollController,
              child: _buildScrollableStatsColumns(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyPlayerInfoColumn() {
    return Column(
      children: [
        // Group Label
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            border: const Border(
              bottom: BorderSide(color: AppColors.primary, width: 1),
            ),
          ),
          child: const Text(
            'Player Info',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Headers
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.primary, width: 1),
            ),
          ),
          child: Row(
            children: [
              _buildHeaderCell(
                'Player',
                widget.columnWidths['Player']!,
                AppColors.primary,
              ),
              _buildHeaderCell(
                'Jersey',
                widget.columnWidths['Jersey']!,
                AppColors.primary,
                isLast: true,
              ),
            ],
          ),
        ),
        // Player Data - No scrolling needed, show all players
        Column(
          children: widget.teamPlayers.map((player) {
            return Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              child: Row(
                children: [
                  _buildDataCell(
                    player.fullName,
                    widget.columnWidths['Player']!,
                    AppColors.primary,
                  ),
                  _buildDataCell(
                    player.jerseyNumber?.toString() ?? '-',
                    widget.columnWidths['Jersey']!,
                    AppColors.primary,
                    isLast: true,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScrollableStatsColumns() {
    return Column(
      children: [
        // Headers Row
        _buildHeadersRow(),
        // Data Rows - Use stats scroll controller (master)
        _buildDataRows(),
      ],
    );
  }

  Widget _buildHeadersRow() {
    return Row(
      children: [
        // Serving Headers
        _buildServingHeaders(),
        // Passing Headers
        _buildPassingHeaders(),
        // Attacking Headers
        _buildAttackingHeaders(),
        // Blocking Headers
        _buildBlockingHeaders(),
        // Dig Headers
        _buildDigHeaders(),
        // Set Headers
        _buildSetHeaders(),
      ],
    );
  }

  Widget _buildDataRows() {
    return Column(
      children: widget.teamPlayers.map((player) {
        final playerEvents = widget.teamEvents
            .where((event) => event.player.id == player.id)
            .toList();
        final servingStats = widget.getPlayerServingStats(playerEvents);
        final passingStats = widget.getPlayerPassingStats(playerEvents);
        final attackingStats = widget.getPlayerAttackingStats(playerEvents);
        final blockingStats = widget.getPlayerBlockingStats(playerEvents);
        final digStats = widget.getPlayerDigStats(playerEvents);
        final setStats = widget.getPlayerSetStats(playerEvents);

        final total = attackingStats['total'] as int;
        final kill = attackingStats['kill'] as int;
        final error = attackingStats['error'] as int;
        final hitPercentage = total > 0 ? (kill - error) / total : 0.0;
        final hitPercentageString = _formatHitPercentage(hitPercentage);

        return Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
          ),
          child: Row(
            children: [
              // Serving Data
              _buildServingDataRow(servingStats),
              // Passing Data
              _buildPassingDataRow(passingStats),
              // Attacking Data
              _buildAttackingDataRow(attackingStats, hitPercentageString),
              // Blocking Data
              _buildBlockingDataRow(blockingStats),
              // Dig Data
              _buildDigDataRow(digStats),
              // Set Data
              _buildSetDataRow(setStats),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServingHeaders() {
    return Container(
      width:
          widget.columnWidths['Serves']! +
          widget.columnWidths['Aces']! +
          widget.columnWidths['In']! +
          widget.columnWidths['Errors']! +
          widget.columnWidths['Float']! +
          widget.columnWidths['Hybrid']! +
          widget.columnWidths['Spin']!,
      child: Column(
        children: [
          // Group Label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.2),
              border: const Border(
                bottom: BorderSide(color: AppColors.secondary, width: 1),
              ),
            ),
            child: const Text(
              'Serving',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Headers
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.secondary, width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell(
                  'Serves',
                  widget.columnWidths['Serves']!,
                  AppColors.secondary,
                ),
                _buildHeaderCell(
                  'Aces',
                  widget.columnWidths['Aces']!,
                  AppColors.secondary,
                ),
                _buildHeaderCell(
                  'In',
                  widget.columnWidths['In']!,
                  AppColors.secondary,
                ),
                _buildHeaderCell(
                  'Errors',
                  widget.columnWidths['Errors']!,
                  AppColors.secondary,
                ),
                _buildHeaderCell(
                  'Float',
                  widget.columnWidths['Float']!,
                  AppColors.secondary,
                ),
                _buildHeaderCell(
                  'Hybrid',
                  widget.columnWidths['Hybrid']!,
                  AppColors.secondary,
                ),
                _buildHeaderCell(
                  'Spin',
                  widget.columnWidths['Spin']!,
                  AppColors.secondary,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassingHeaders() {
    return Container(
      width:
          widget.columnWidths['Passes']! +
          widget.columnWidths['Average']! +
          widget.columnWidths['Ace']! +
          widget.columnWidths['0']! +
          widget.columnWidths['1']! +
          widget.columnWidths['2']! +
          widget.columnWidths['3']!,
      child: Column(
        children: [
          // Group Label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              border: const Border(
                bottom: BorderSide(color: AppColors.primary, width: 1),
              ),
            ),
            child: const Text(
              'Passing',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Headers
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.primary, width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell(
                  'Passes',
                  widget.columnWidths['Passes']!,
                  AppColors.primary,
                ),
                _buildHeaderCell(
                  'Average',
                  widget.columnWidths['Average']!,
                  AppColors.primary,
                ),
                _buildHeaderCell(
                  'Ace',
                  widget.columnWidths['Ace']!,
                  AppColors.primary,
                ),
                _buildHeaderCell(
                  '0',
                  widget.columnWidths['0']!,
                  AppColors.primary,
                ),
                _buildHeaderCell(
                  '1',
                  widget.columnWidths['1']!,
                  AppColors.primary,
                ),
                _buildHeaderCell(
                  '2',
                  widget.columnWidths['2']!,
                  AppColors.primary,
                ),
                _buildHeaderCell(
                  '3',
                  widget.columnWidths['3']!,
                  AppColors.primary,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttackingHeaders() {
    return Container(
      width:
          widget.columnWidths['Attacks']! +
          widget.columnWidths['Kills']! +
          widget.columnWidths['In']! +
          widget.columnWidths['Errors']! +
          widget.columnWidths['Hit %']!,
      child: Column(
        children: [
          // Group Label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0097A7).withValues(alpha: 0.2),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF0097A7), width: 1),
              ),
            ),
            child: const Text(
              'Attacking',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0097A7),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Headers
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF0097A7), width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell(
                  'Attacks',
                  widget.columnWidths['Attacks']!,
                  const Color(0xFF0097A7),
                ),
                _buildHeaderCell(
                  'Kills',
                  widget.columnWidths['Kills']!,
                  const Color(0xFF0097A7),
                ),
                _buildHeaderCell(
                  'In',
                  widget.columnWidths['In']!,
                  const Color(0xFF0097A7),
                ),
                _buildHeaderCell(
                  'Errors',
                  widget.columnWidths['Errors']!,
                  const Color(0xFF0097A7),
                ),
                _buildHeaderCell(
                  'Hit %',
                  widget.columnWidths['Hit %']!,
                  const Color(0xFF0097A7),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingDataRow(Map<String, dynamic> servingStats) {
    return Container(
      width:
          widget.columnWidths['Serves']! +
          widget.columnWidths['Aces']! +
          widget.columnWidths['In']! +
          widget.columnWidths['Errors']! +
          widget.columnWidths['Float']! +
          widget.columnWidths['Hybrid']! +
          widget.columnWidths['Spin']!,
      child: Row(
        children: [
          _buildDataCell(
            servingStats['total'].toString(),
            widget.columnWidths['Serves']!,
            AppColors.secondary,
          ),
          _buildDataCell(
            (servingStats['ace'] ?? 0).toString(),
            widget.columnWidths['Aces']!,
            AppColors.secondary,
          ),
          _buildDataCell(
            servingStats['in'].toString(),
            widget.columnWidths['In']!,
            AppColors.secondary,
          ),
          _buildDataCell(
            servingStats['error'].toString(),
            widget.columnWidths['Errors']!,
            AppColors.secondary,
          ),
          _buildDataCell(
            servingStats['float'].toString(),
            widget.columnWidths['Float']!,
            AppColors.secondary,
          ),
          _buildDataCell(
            servingStats['hybrid'].toString(),
            widget.columnWidths['Hybrid']!,
            AppColors.secondary,
          ),
          _buildDataCell(
            servingStats['spin'].toString(),
            widget.columnWidths['Spin']!,
            AppColors.secondary,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPassingDataRow(Map<String, dynamic> passingStats) {
    return Container(
      width:
          widget.columnWidths['Passes']! +
          widget.columnWidths['Average']! +
          widget.columnWidths['Ace']! +
          widget.columnWidths['0']! +
          widget.columnWidths['1']! +
          widget.columnWidths['2']! +
          widget.columnWidths['3']!,
      child: Row(
        children: [
          _buildDataCell(
            passingStats['total'].toString(),
            widget.columnWidths['Passes']!,
            AppColors.primary,
          ),
          _buildDataCell(
            (passingStats['average'] as double).toStringAsFixed(2),
            widget.columnWidths['Average']!,
            AppColors.primary,
          ),
          _buildDataCell(
            passingStats['ace'].toString(),
            widget.columnWidths['Ace']!,
            AppColors.primary,
          ),
          _buildDataCell(
            passingStats['0'].toString(),
            widget.columnWidths['0']!,
            AppColors.primary,
          ),
          _buildDataCell(
            passingStats['1'].toString(),
            widget.columnWidths['1']!,
            AppColors.primary,
          ),
          _buildDataCell(
            passingStats['2'].toString(),
            widget.columnWidths['2']!,
            AppColors.primary,
          ),
          _buildDataCell(
            passingStats['3'].toString(),
            widget.columnWidths['3']!,
            AppColors.primary,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAttackingDataRow(
    Map<String, dynamic> attackingStats,
    String hitPercentageString,
  ) {
    return Container(
      width:
          widget.columnWidths['Attacks']! +
          widget.columnWidths['Kills']! +
          widget.columnWidths['In']! +
          widget.columnWidths['Errors']! +
          widget.columnWidths['Hit %']!,
      child: Row(
        children: [
          _buildDataCell(
            attackingStats['total'].toString(),
            widget.columnWidths['Attacks']!,
            const Color(0xFF0097A7),
          ),
          _buildDataCell(
            attackingStats['kill'].toString(),
            widget.columnWidths['Kills']!,
            const Color(0xFF0097A7),
          ),
          _buildDataCell(
            attackingStats['in'].toString(),
            widget.columnWidths['In']!,
            const Color(0xFF0097A7),
          ),
          _buildDataCell(
            attackingStats['error'].toString(),
            widget.columnWidths['Errors']!,
            const Color(0xFF0097A7),
          ),
          _buildDataCell(
            hitPercentageString,
            widget.columnWidths['Hit %']!,
            const Color(0xFF0097A7),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String text,
    double width,
    Color color, {
    bool isLast = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(right: BorderSide(color: color, width: 1)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildDataCell(
    String text,
    double width,
    Color color, {
    bool isLast = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(right: BorderSide(color: color, width: 1)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildBlockingHeaders() {
    return Container(
      width:
          widget.columnWidths['Blocks']! +
          widget.columnWidths['Solo']! +
          widget.columnWidths['Assist']! +
          widget.columnWidths['Error']!,
      child: Column(
        children: [
          // Group Label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFFF6B6B), width: 1),
              ),
            ),
            child: const Text(
              'Blocking',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B6B),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Column Headers
          Row(
            children: [
              _buildHeaderCell(
                'Blocks',
                widget.columnWidths['Blocks']!,
                const Color(0xFFFF6B6B),
              ),
              _buildHeaderCell(
                'Solo',
                widget.columnWidths['Solo']!,
                const Color(0xFFFF6B6B),
              ),
              _buildHeaderCell(
                'Assist',
                widget.columnWidths['Assist']!,
                const Color(0xFFFF6B6B),
              ),
              _buildHeaderCell(
                'Error',
                widget.columnWidths['Error']!,
                const Color(0xFFFF6B6B),
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigHeaders() {
    return Container(
      width:
          widget.columnWidths['Digs']! +
          widget.columnWidths['Overhand']! +
          widget.columnWidths['Platform']!,
      child: Column(
        children: [
          // Group Label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF4CAF50), width: 1),
              ),
            ),
            child: const Text(
              'Dig',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Column Headers
          Row(
            children: [
              _buildHeaderCell(
                'Digs',
                widget.columnWidths['Digs']!,
                const Color(0xFF4CAF50),
              ),
              _buildHeaderCell(
                'Overhand',
                widget.columnWidths['Overhand']!,
                const Color(0xFF4CAF50),
              ),
              _buildHeaderCell(
                'Platform',
                widget.columnWidths['Platform']!,
                const Color(0xFF4CAF50),
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetHeaders() {
    return Container(
      width:
          widget.columnWidths['Sets']! +
          widget.columnWidths['In System']! +
          widget.columnWidths['Out of System']!,
      child: Column(
        children: [
          // Group Label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.2),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF2196F3), width: 1),
              ),
            ),
            child: const Text(
              'Set',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Column Headers
          Row(
            children: [
              _buildHeaderCell(
                'Sets',
                widget.columnWidths['Sets']!,
                const Color(0xFF2196F3),
              ),
              _buildHeaderCell(
                'In System',
                widget.columnWidths['In System']!,
                const Color(0xFF2196F3),
              ),
              _buildHeaderCell(
                'Out of System',
                widget.columnWidths['Out of System']!,
                const Color(0xFF2196F3),
                isLast: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockingDataRow(Map<String, int> blockingStats) {
    return Row(
      children: [
        _buildDataCell(
          blockingStats['total'].toString(),
          widget.columnWidths['Blocks']!,
          const Color(0xFFFF6B6B),
        ),
        _buildDataCell(
          blockingStats['solo'].toString(),
          widget.columnWidths['Solo']!,
          const Color(0xFFFF6B6B),
        ),
        _buildDataCell(
          blockingStats['assist'].toString(),
          widget.columnWidths['Assist']!,
          const Color(0xFFFF6B6B),
        ),
        _buildDataCell(
          blockingStats['error'].toString(),
          widget.columnWidths['Error']!,
          const Color(0xFFFF6B6B),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildDigDataRow(Map<String, int> digStats) {
    return Row(
      children: [
        _buildDataCell(
          digStats['total'].toString(),
          widget.columnWidths['Digs']!,
          const Color(0xFF4CAF50),
        ),
        _buildDataCell(
          digStats['overhand'].toString(),
          widget.columnWidths['Overhand']!,
          const Color(0xFF4CAF50),
        ),
        _buildDataCell(
          digStats['platform'].toString(),
          widget.columnWidths['Platform']!,
          const Color(0xFF4CAF50),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildSetDataRow(Map<String, int> setStats) {
    return Row(
      children: [
        _buildDataCell(
          setStats['total'].toString(),
          widget.columnWidths['Sets']!,
          const Color(0xFF2196F3),
        ),
        _buildDataCell(
          setStats['in_system'].toString(),
          widget.columnWidths['In System']!,
          const Color(0xFF2196F3),
        ),
        _buildDataCell(
          setStats['out_of_system'].toString(),
          widget.columnWidths['Out of System']!,
          const Color(0xFF2196F3),
          isLast: true,
        ),
      ],
    );
  }
}
