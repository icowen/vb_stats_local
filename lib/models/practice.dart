import 'team.dart';

class Practice {
  final int? id;
  final Team team;
  final DateTime date;

  Practice({this.id, required this.team, required this.date});

  Map<String, dynamic> toMap() {
    return {'id': id, 'teamId': team.id, 'date': date.millisecondsSinceEpoch};
  }

  factory Practice.fromMap(Map<String, dynamic> map, {Team? team}) {
    return Practice(
      id: map['id'],
      team: team ?? Team.fromMap({'id': map['teamId']}),
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
    );
  }

  Practice copyWith({int? id, Team? team, DateTime? date}) {
    return Practice(
      id: id ?? this.id,
      team: team ?? this.team,
      date: date ?? this.date,
    );
  }

  String get practiceTitle => '${team.teamName} Practice';

  @override
  String toString() {
    return 'Practice{id: $id, team: ${team.teamName}, date: $date}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Practice &&
        other.id == id &&
        other.team == team &&
        other.date == date;
  }

  @override
  int get hashCode {
    return id.hashCode ^ team.hashCode ^ date.hashCode;
  }
}
