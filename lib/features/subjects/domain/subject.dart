class Subject {
  final int? id;
  final String courseCode;
  final String courseTitle;
  final int year; // 1, 2, 3, 4
  final int semester; // 1 to 8
  final String subjectType; // Theory, Lab, Project, Additional
  final int faculty1Id;
  final int? faculty2Id;
  final int? faculty3Id;

  // Resolved names (optional, populated via joins)
  final String? faculty1Name;
  final String? faculty2Name;
  final String? faculty3Name;

  Subject({
    this.id,
    required this.courseCode,
    required this.courseTitle,
    required this.year,
    required this.semester,
    required this.subjectType,
    required this.faculty1Id,
    this.faculty2Id,
    this.faculty3Id,
    this.faculty1Name,
    this.faculty2Name,
    this.faculty3Name,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'course_code': courseCode,
      'course_title': courseTitle,
      'year': year,
      'semester': semester,
      'subject_type': subjectType,
      'faculty1_id': faculty1Id,
      'faculty2_id': faculty2Id,
      'faculty3_id': faculty3Id,
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as int?,
      courseCode: map['course_code'] as String,
      courseTitle: map['course_title'] as String,
      year: map['year'] as int,
      semester: map['semester'] as int,
      subjectType: map['subject_type'] as String,
      faculty1Id: map['faculty1_id'] as int,
      faculty2Id: map['faculty2_id'] as int?,
      faculty3Id: map['faculty3_id'] as int?,
      faculty1Name: map['faculty1_name'] as String?,
      faculty2Name: map['faculty2_name'] as String?,
      faculty3Name: map['faculty3_name'] as String?,
    );
  }

  Subject copyWith({
    int? id,
    String? courseCode,
    String? courseTitle,
    int? year,
    int? semester,
    String? subjectType,
    int? faculty1Id,
    int? faculty2Id,
    int? faculty3Id,
    String? faculty1Name,
    String? faculty2Name,
    String? faculty3Name,
  }) {
    return Subject(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      courseTitle: courseTitle ?? this.courseTitle,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      subjectType: subjectType ?? this.subjectType,
      faculty1Id: faculty1Id ?? this.faculty1Id,
      faculty2Id: faculty2Id ?? this.faculty2Id,
      faculty3Id: faculty3Id ?? this.faculty3Id,
      faculty1Name: faculty1Name ?? this.faculty1Name,
      faculty2Name: faculty2Name ?? this.faculty2Name,
      faculty3Name: faculty3Name ?? this.faculty3Name,
    );
  }

  // Returns a nice display list of all assigned faculties
  List<String> get facultyNames {
    final list = <String>[];
    if (faculty1Name != null && faculty1Name!.isNotEmpty) list.add(faculty1Name!);
    if (faculty2Name != null && faculty2Name!.isNotEmpty) list.add(faculty2Name!);
    if (faculty3Name != null && faculty3Name!.isNotEmpty) list.add(faculty3Name!);
    return list;
  }
}
