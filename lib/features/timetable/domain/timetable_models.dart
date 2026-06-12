import '../../subjects/domain/subject.dart';

class HistoryRecord {
  final int? id;
  final String name;
  final String dateGenerated;
  final String timeGenerated;
  final String createdTimestamp;
  final String pdfPath;
  final String excelPath;

  HistoryRecord({
    this.id,
    required this.name,
    required this.dateGenerated,
    required this.timeGenerated,
    required this.createdTimestamp,
    required this.pdfPath,
    required this.excelPath,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'date_generated': dateGenerated,
      'time_generated': timeGenerated,
      'created_timestamp': createdTimestamp,
      'pdf_path': pdfPath,
      'excel_path': excelPath,
    };
  }

  factory HistoryRecord.fromMap(Map<String, dynamic> map) {
    return HistoryRecord(
      id: map['id'] as int?,
      name: map['name'] as String,
      dateGenerated: map['date_generated'] as String,
      timeGenerated: map['time_generated'] as String,
      createdTimestamp: map['created_timestamp'] as String,
      pdfPath: map['pdf_path'] as String,
      excelPath: map['excel_path'] as String,
    );
  }

  HistoryRecord copyWith({
    int? id,
    String? name,
    String? dateGenerated,
    String? timeGenerated,
    String? createdTimestamp,
    String? pdfPath,
    String? excelPath,
  }) {
    return HistoryRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      dateGenerated: dateGenerated ?? this.dateGenerated,
      timeGenerated: timeGenerated ?? this.timeGenerated,
      createdTimestamp: createdTimestamp ?? this.createdTimestamp,
      pdfPath: pdfPath ?? this.pdfPath,
      excelPath: excelPath ?? this.excelPath,
    );
  }
}

class TimetableInput {
  final int historyId;
  final int subjectId;
  final int hoursPerWeek;
  final Subject? subject; // Resolved subject details

  TimetableInput({
    required this.historyId,
    required this.subjectId,
    required this.hoursPerWeek,
    this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      'history_id': historyId,
      'subject_id': subjectId,
      'hours_per_week': hoursPerWeek,
    };
  }

  factory TimetableInput.fromMap(Map<String, dynamic> map, {Subject? subject}) {
    return TimetableInput(
      historyId: map['history_id'] as int,
      subjectId: map['subject_id'] as int,
      hoursPerWeek: map['hours_per_week'] as int,
      subject: subject,
    );
  }
}

class TimetableSlot {
  final int? id;
  final int historyId;
  final int year;
  final int day; // 0 (Mon) to 4 (Fri)
  final int period; // 0 to 7
  final int? subjectId;
  final Subject? subject; // Resolved subject details

  TimetableSlot({
    this.id,
    required this.historyId,
    required this.year,
    required this.day,
    required this.period,
    this.subjectId,
    this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'history_id': historyId,
      'year': year,
      'day': day,
      'period': period,
      'subject_id': subjectId,
    };
  }

  factory TimetableSlot.fromMap(Map<String, dynamic> map, {Subject? subject}) {
    return TimetableSlot(
      id: map['id'] as int?,
      historyId: map['history_id'] as int,
      year: map['year'] as int,
      day: map['day'] as int,
      period: map['period'] as int,
      subjectId: map['subject_id'] as int?,
      subject: subject,
    );
  }

  TimetableSlot copyWith({
    int? id,
    int? historyId,
    int? year,
    int? day,
    int? period,
    int? subjectId,
    Subject? subject,
  }) {
    return TimetableSlot(
      id: id ?? this.id,
      historyId: historyId ?? this.historyId,
      year: year ?? this.year,
      day: day ?? this.day,
      period: period ?? this.period,
      subjectId: subjectId ?? this.subjectId,
      subject: subject ?? this.subject,
    );
  }
}
