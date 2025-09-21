import 'team.dart';

class Match {
  final int? id;
  final Team? homeTeam;
  final Team? awayTeam;
  final DateTime? startTime;

  Match({
    this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.startTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'homeTeamId': homeTeam?.id,
      'awayTeamId': awayTeam?.id,
      'startTime': startTime?.millisecondsSinceEpoch,
    };
  }

  factory Match.fromMap(
    Map<String, dynamic> map, {
    Team? homeTeam,
    Team? awayTeam,
  }) {
    return Match(
      id: map['id'],
      homeTeam: homeTeam ?? Team.fromMap({'id': map['homeTeamId']}),
      awayTeam: awayTeam ?? Team.fromMap({'id': map['awayTeamId']}),
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
    );
  }

  Match copyWith({
    int? id,
    Team? homeTeam,
    Team? awayTeam,
    DateTime? startTime,
  }) {
    return Match(
      id: id ?? this.id,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      startTime: startTime ?? this.startTime,
    );
  }

  String get matchTitle => '${homeTeam?.teamName} vs ${awayTeam?.teamName}';

  @override
  String toString() {
    return 'Match{id: $id, homeTeam: ${homeTeam?.teamName}, awayTeam: ${awayTeam?.teamName}, startTime: $startTime}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Match &&
        other.id == id &&
        other.homeTeam == homeTeam &&
        other.awayTeam == awayTeam &&
        other.startTime == startTime;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        homeTeam.hashCode ^
        awayTeam.hashCode ^
        startTime.hashCode;
  }
}
