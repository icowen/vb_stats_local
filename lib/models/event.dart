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

  Event({
    this.id,
    this.practice,
    this.match,
    required this.player,
    required this.team,
    required this.type,
    required this.metadata,
    required this.timestamp,
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

  Event copyWith({
    int? id,
    Practice? practice,
    Match? match,
    Player? player,
    Team? team,
    EventType? type,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
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
    );
  }

  @override
  String toString() {
    return 'Event{id: $id, type: ${type.name}, player: ${player.fullName}, team: ${team.teamName}, metadata: $metadata, timestamp: $timestamp}';
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
        other.timestamp == timestamp;
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
        timestamp.hashCode;
  }
}

enum EventType {
  serve('Serve'),
  pass('Pass'),
  attack('Attack'),
  block('Block'),
  dig('Dig'),
  set('Set');

  const EventType(this.displayName);
  final String displayName;
}
