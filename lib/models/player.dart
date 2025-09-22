class Player {
  final int? id;
  final String? firstName;
  final String? lastName;
  final int? jerseyNumber;
  final int? teamId;

  Player({
    this.id,
    required this.firstName,
    required this.lastName,
    this.jerseyNumber,
    this.teamId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'jerseyNumber': jerseyNumber,
      'teamId': teamId,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      jerseyNumber: map['jerseyNumber'],
      teamId: map['teamId'],
    );
  }

  String get fullName => '$firstName $lastName';

  String get jerseyDisplay =>
      jerseyNumber == null ? 'No Jersey' : '#$jerseyNumber';

  @override
  String toString() {
    return 'Player{id: $id, firstName: $firstName, lastName: $lastName, jerseyNumber: $jerseyNumber, teamId: $teamId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Player &&
        other.id == id &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.jerseyNumber == jerseyNumber &&
        other.teamId == teamId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        firstName.hashCode ^
        lastName.hashCode ^
        jerseyNumber.hashCode ^
        teamId.hashCode;
  }
}
