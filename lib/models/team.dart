import 'player.dart';

class Team {
  final int? id;
  final String teamName;
  final String clubName;
  final int age;
  final List<Player> players;

  Team({
    this.id,
    required this.teamName,
    required this.clubName,
    required this.age,
    this.players = const [],
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'teamName': teamName, 'clubName': clubName, 'age': age};
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'],
      teamName: map['teamName'],
      clubName: map['clubName'],
      age: map['age'],
      players: [], // Players will be loaded separately
    );
  }

  Team copyWith({
    int? id,
    String? teamName,
    String? clubName,
    int? age,
    List<Player>? players,
  }) {
    return Team(
      id: id ?? this.id,
      teamName: teamName ?? this.teamName,
      clubName: clubName ?? this.clubName,
      age: age ?? this.age,
      players: players ?? this.players,
    );
  }

  @override
  String toString() {
    return 'Team{id: $id, teamName: $teamName, clubName: $clubName, age: $age, players: ${players.length}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Team &&
        other.id == id &&
        other.teamName == teamName &&
        other.clubName == clubName &&
        other.age == age;
  }

  @override
  int get hashCode {
    return id.hashCode ^ teamName.hashCode ^ clubName.hashCode ^ age.hashCode;
  }
}
