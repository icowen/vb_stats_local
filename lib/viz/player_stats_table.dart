import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/event.dart';

class PlayerStatsTable extends StatefulWidget {
  final Map<String, double> columnWidths;
  final List<Player> teamPlayers;
  final List<Event> teamEvents;
  final Function(List<Event>) getPlayerServingStats;
  final Function(List<Event>) getPlayerPassingStats;
  final Function(List<Event>) getPlayerAttackingStats;

  const PlayerStatsTable({
    super.key,
    required this.columnWidths,
    required this.teamPlayers,
    required this.teamEvents,
    required this.getPlayerServingStats,
    required this.getPlayerPassingStats,
    required this.getPlayerAttackingStats,
  });

  @override
  State<PlayerStatsTable> createState() => _PlayerStatsTableState();
}

class _PlayerStatsTableState extends State<PlayerStatsTable> {
  late ScrollController _statsScrollController;
  late ScrollController _stickyScrollController;

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
    _stickyScrollController = ScrollController();

    // Listen to stats scroll changes and sync sticky column
    _statsScrollController.addListener(_syncScrollPositions);
  }

  @override
  void dispose() {
    _statsScrollController.removeListener(_syncScrollPositions);
    _statsScrollController.dispose();
    _stickyScrollController.dispose();
    super.dispose();
  }

  void _syncScrollPositions() {
    if (_stickyScrollController.hasClients) {
      _stickyScrollController.jumpTo(_statsScrollController.offset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 400,
        child: Row(
          children: [
            // Sticky Player Info Columns
            Container(
              width:
                  widget.columnWidths['Player']! +
                  widget.columnWidths['Jersey']!,
              child: _buildStickyPlayerInfoColumn(),
            ),
            // Vertical border between player info and stats
            Container(width: 1, color: Colors.grey),
            // Scrollable Stats Columns
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildScrollableStatsColumns(),
              ),
            ),
          ],
        ),
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
            color: const Color(0xFF00E5FF).withOpacity(0.2),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF00E5FF), width: 1),
            ),
          ),
          child: const Text(
            'Player Info',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF00E5FF),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Headers
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF00E5FF), width: 1),
            ),
          ),
          child: Row(
            children: [
              _buildHeaderCell(
                'Player',
                widget.columnWidths['Player']!,
                const Color(0xFF00E5FF),
              ),
              _buildHeaderCell(
                'Jersey',
                widget.columnWidths['Jersey']!,
                const Color(0xFF00E5FF),
                isLast: true,
              ),
            ],
          ),
        ),
        // Player Data - Use sticky scroll controller (synced with stats)
        Expanded(
          child: SingleChildScrollView(
            controller: _stickyScrollController,
            child: Column(
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
                        const Color(0xFF00E5FF),
                      ),
                      _buildDataCell(
                        player.jerseyNumber?.toString() ?? '-',
                        widget.columnWidths['Jersey']!,
                        const Color(0xFF00E5FF),
                        isLast: true,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
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
        Expanded(
          child: SingleChildScrollView(
            controller: _statsScrollController,
            child: _buildDataRows(),
          ),
        ),
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
              color: const Color(0xFF00FF88).withOpacity(0.2),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF00FF88), width: 1),
              ),
            ),
            child: const Text(
              'Serving',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00FF88),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Headers
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF00FF88), width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell(
                  'Serves',
                  widget.columnWidths['Serves']!,
                  const Color(0xFF00FF88),
                ),
                _buildHeaderCell(
                  'Aces',
                  widget.columnWidths['Aces']!,
                  const Color(0xFF00FF88),
                ),
                _buildHeaderCell(
                  'In',
                  widget.columnWidths['In']!,
                  const Color(0xFF00FF88),
                ),
                _buildHeaderCell(
                  'Errors',
                  widget.columnWidths['Errors']!,
                  const Color(0xFF00FF88),
                ),
                _buildHeaderCell(
                  'Float',
                  widget.columnWidths['Float']!,
                  const Color(0xFF00FF88),
                ),
                _buildHeaderCell(
                  'Hybrid',
                  widget.columnWidths['Hybrid']!,
                  const Color(0xFF00FF88),
                ),
                _buildHeaderCell(
                  'Spin',
                  widget.columnWidths['Spin']!,
                  const Color(0xFF00FF88),
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
              color: const Color(0xFF00E5FF).withOpacity(0.2),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF00E5FF), width: 1),
              ),
            ),
            child: const Text(
              'Passing',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Headers
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF00E5FF), width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell(
                  'Passes',
                  widget.columnWidths['Passes']!,
                  const Color(0xFF00E5FF),
                ),
                _buildHeaderCell(
                  'Average',
                  widget.columnWidths['Average']!,
                  const Color(0xFF00E5FF),
                ),
                _buildHeaderCell(
                  'Ace',
                  widget.columnWidths['Ace']!,
                  const Color(0xFF00E5FF),
                ),
                _buildHeaderCell(
                  '0',
                  widget.columnWidths['0']!,
                  const Color(0xFF00E5FF),
                ),
                _buildHeaderCell(
                  '1',
                  widget.columnWidths['1']!,
                  const Color(0xFF00E5FF),
                ),
                _buildHeaderCell(
                  '2',
                  widget.columnWidths['2']!,
                  const Color(0xFF00E5FF),
                ),
                _buildHeaderCell(
                  '3',
                  widget.columnWidths['3']!,
                  const Color(0xFF00E5FF),
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
              color: const Color(0xFF0097A7).withOpacity(0.2),
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
            const Color(0xFF00FF88),
          ),
          _buildDataCell(
            (servingStats['ace'] ?? 0).toString(),
            widget.columnWidths['Aces']!,
            const Color(0xFF00FF88),
          ),
          _buildDataCell(
            servingStats['in'].toString(),
            widget.columnWidths['In']!,
            const Color(0xFF00FF88),
          ),
          _buildDataCell(
            servingStats['error'].toString(),
            widget.columnWidths['Errors']!,
            const Color(0xFF00FF88),
          ),
          _buildDataCell(
            servingStats['float'].toString(),
            widget.columnWidths['Float']!,
            const Color(0xFF00FF88),
          ),
          _buildDataCell(
            servingStats['hybrid'].toString(),
            widget.columnWidths['Hybrid']!,
            const Color(0xFF00FF88),
          ),
          _buildDataCell(
            servingStats['spin'].toString(),
            widget.columnWidths['Spin']!,
            const Color(0xFF00FF88),
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
            const Color(0xFF00E5FF),
          ),
          _buildDataCell(
            (passingStats['average'] as double).toStringAsFixed(2),
            widget.columnWidths['Average']!,
            const Color(0xFF00E5FF),
          ),
          _buildDataCell(
            passingStats['ace'].toString(),
            widget.columnWidths['Ace']!,
            const Color(0xFF00E5FF),
          ),
          _buildDataCell(
            passingStats['0'].toString(),
            widget.columnWidths['0']!,
            const Color(0xFF00E5FF),
          ),
          _buildDataCell(
            passingStats['1'].toString(),
            widget.columnWidths['1']!,
            const Color(0xFF00E5FF),
          ),
          _buildDataCell(
            passingStats['2'].toString(),
            widget.columnWidths['2']!,
            const Color(0xFF00E5FF),
          ),
          _buildDataCell(
            passingStats['3'].toString(),
            widget.columnWidths['3']!,
            const Color(0xFF00E5FF),
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
}
