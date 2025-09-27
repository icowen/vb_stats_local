import 'package:vb_stats_local/models/player.dart';
import 'package:vb_stats_local/models/team.dart';
import 'package:vb_stats_local/models/practice.dart';
import 'package:vb_stats_local/models/match.dart';

class Event {
  final int? id;
  final Practice? practice;
  final Match? match;
  final Player player;
  final Team team;
  final EventType type;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final double? fromX;
  final double? fromY;
  final double? toX;
  final double? toY;

  Event({
    this.id,
    this.practice,
    this.match,
    required this.player,
    required this.team,
    required this.type,
    required this.metadata,
    required this.timestamp,
    this.fromX,
    this.fromY,
    this.toX,
    this.toY,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'practiceId': practice?.id,
      'matchId': match?.id,
      'playerId': player.id,
      'teamId': team.id,
      'type': type.name,
      'metadata': _mapToString(metadata),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'fromX': fromX,
      'fromY': fromY,
      'toX': toX,
      'toY': toY,
    };
  }

  factory Event.fromMap(
    Map<String, dynamic> map, {
    required Player player,
    required Team team,
    Practice? practice,
    Match? match,
  }) {
    return Event(
      id: map['id'],
      practice: practice,
      match: match,
      player: player,
      team: team,
      type: EventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => EventType.serve,
      ),
      metadata: _stringToMap(map['metadata']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      fromX: map['fromX']?.toDouble(),
      fromY: map['fromY']?.toDouble(),
      toX: map['toX']?.toDouble(),
      toY: map['toY']?.toDouble(),
    );
  }

  // Helper methods to convert Map to/from JSON string for storage
  static String _mapToString(Map<String, dynamic> map) {
    final entries = map.entries.map((e) => '${e.key}:${e.value}').join('|');
    return entries;
  }

  static Map<String, dynamic> _stringToMap(String str) {
    if (str.isEmpty) return {};
    final entries = str.split('|');
    final map = <String, dynamic>{};
    for (final entry in entries) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  // Convenience getters
  String get eventTitle => '${type.displayName} - ${player.fullName}';
  String get contextTitle =>
      practice?.practiceTitle ?? match?.matchTitle ?? 'Unknown';
  bool get isPractice => practice != null;
  bool get isMatch => match != null;

  // Coordinate convenience methods
  bool get hasFromCoordinates => fromX != null && fromY != null;
  bool get hasToCoordinates => toX != null && toY != null;
  bool get hasCoordinates => hasFromCoordinates || hasToCoordinates;

  String get coordinateInfo {
    if (!hasCoordinates) return 'No coordinates';
    final from = hasFromCoordinates
        ? '(${fromX!.toStringAsFixed(1)}, ${fromY!.toStringAsFixed(1)})'
        : 'Unknown';
    final to = hasToCoordinates
        ? '(${toX!.toStringAsFixed(1)}, ${toY!.toStringAsFixed(1)})'
        : 'Unknown';
    return 'From: $from → To: $to';
  }

  Event copyWith({
    int? id,
    Practice? practice,
    Match? match,
    Player? player,
    Team? team,
    EventType? type,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    double? fromX,
    double? fromY,
    double? toX,
    double? toY,
  }) {
    return Event(
      id: id ?? this.id,
      practice: practice ?? this.practice,
      match: match ?? this.match,
      player: player ?? this.player,
      team: team ?? this.team,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      fromX: fromX ?? this.fromX,
      fromY: fromY ?? this.fromY,
      toX: toX ?? this.toX,
      toY: toY ?? this.toY,
    );
  }

  @override
  String toString() {
    return 'Event{id: $id, type: ${type.name}, player: ${player.fullName}, team: ${team.teamName}, metadata: $metadata, timestamp: $timestamp, fromX: $fromX, fromY: $fromY, toX: $toX, toY: $toY}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event &&
        other.id == id &&
        other.practice == practice &&
        other.match == match &&
        other.player == player &&
        other.team == team &&
        other.type == type &&
        other.metadata.toString() == metadata.toString() &&
        other.timestamp == timestamp &&
        other.fromX == fromX &&
        other.fromY == fromY &&
        other.toX == toX &&
        other.toY == toY;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        practice.hashCode ^
        match.hashCode ^
        player.hashCode ^
        team.hashCode ^
        type.hashCode ^
        metadata.hashCode ^
        timestamp.hashCode ^
        fromX.hashCode ^
        fromY.hashCode ^
        toX.hashCode ^
        toY.hashCode;
  }
}

enum EventType {
  serve('Serve'),
  pass('Pass'),
  attack('Attack'),
  block('Block'),
  dig('Dig'),
  set('Set'),
  freeball('Freeball');

  const EventType(this.displayName);
  final String displayName;
}
