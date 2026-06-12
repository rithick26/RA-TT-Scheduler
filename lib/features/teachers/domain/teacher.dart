class Teacher {
  final int? id;
  final String name;
  final String designation;

  Teacher({
    this.id,
    required this.name,
    required this.designation,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'designation': designation,
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] as int?,
      name: map['name'] as String,
      designation: map['designation'] as String,
    );
  }

  Teacher copyWith({
    int? id,
    String? name,
    String? designation,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      designation: designation ?? this.designation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Teacher &&
        other.id == id &&
        other.name == name &&
        other.designation == designation;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ designation.hashCode;
}
