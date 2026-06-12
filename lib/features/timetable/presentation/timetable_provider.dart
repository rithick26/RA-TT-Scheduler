import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/db/db_helper.dart';
import '../../teachers/domain/teacher.dart';
import '../../subjects/domain/subject.dart';
import '../../subjects/presentation/subjects_provider.dart';
import '../domain/timetable_models.dart';
import '../domain/scheduler_solver.dart';
import '../domain/pdf_generator.dart';
import '../domain/excel_generator.dart';

// Represents the state of the Timetable Feature
class TimetableState {
  final AsyncValue<List<HistoryRecord>> historyRecords;
  final Map<int, int> workspaceHours; // subjectId -> hoursPerWeek
  final bool isGenerating;
  final String? generationError;
  final HistoryRecord? activeHistoryRecord;
  final List<TimetableSlot> activeSlots;

  TimetableState({
    required this.historyRecords,
    required this.workspaceHours,
    required this.isGenerating,
    this.generationError,
    this.activeHistoryRecord,
    required this.activeSlots,
  });

  TimetableState copyWith({
    AsyncValue<List<HistoryRecord>>? historyRecords,
    Map<int, int>? workspaceHours,
    bool? isGenerating,
    String? generationError,
    HistoryRecord? activeHistoryRecord,
    List<TimetableSlot>? activeSlots,
  }) {
    return TimetableState(
      historyRecords: historyRecords ?? this.historyRecords,
      workspaceHours: workspaceHours ?? this.workspaceHours,
      isGenerating: isGenerating ?? this.isGenerating,
      generationError: generationError, // Will clear if not explicitly passed
      activeHistoryRecord: activeHistoryRecord ?? this.activeHistoryRecord,
      activeSlots: activeSlots ?? this.activeSlots,
    );
  }
}

final timetableProvider = StateNotifierProvider<TimetableNotifier, TimetableState>((ref) {
  final subjectsState = ref.watch(subjectsProvider);
  return TimetableNotifier(ref, subjectsState);
});

class TimetableNotifier extends StateNotifier<TimetableState> {
  final Ref ref;
  final AsyncValue<List<Subject>> subjectsState;

  TimetableNotifier(this.ref, this.subjectsState)
      : super(TimetableState(
          historyRecords: const AsyncValue.loading(),
          workspaceHours: {},
          isGenerating: false,
          activeSlots: [],
        )) {
    loadHistory();
  }

  final _dbHelper = DbHelper();

  // Load generation history from database
  Future<void> loadHistory() async {
    state = state.copyWith(historyRecords: const AsyncValue.loading());
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'history_records',
        orderBy: 'created_timestamp DESC',
      );
      final list = maps.map((map) => HistoryRecord.fromMap(map)).toList();
      state = state.copyWith(historyRecords: AsyncValue.data(list));
    } catch (e, stack) {
      state = state.copyWith(historyRecords: AsyncValue.error(e, stack));
    }
  }

  // Update hours input for a specific subject
  void updateWorkspaceHour(int subjectId, int hours) {
    final updated = Map<int, int>.from(state.workspaceHours);
    if (hours <= 0) {
      updated.remove(subjectId);
    } else {
      updated[subjectId] = hours;
    }
    state = state.copyWith(workspaceHours: updated, generationError: null);
  }

  // Set the hours for multiple subjects (e.g. initial setup)
  void setWorkspaceHours(Map<int, int> hours) {
    state = state.copyWith(workspaceHours: Map<int, int>.from(hours), generationError: null);
  }

  // Pre-load inputs and details from an old history record
  Future<void> duplicateTimetable(HistoryRecord record) async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'timetable_inputs',
        where: 'history_id = ?',
        whereArgs: [record.id],
      );

      final duplicatedInputs = <int, int>{};
      for (final map in maps) {
        final subjectId = map['subject_id'] as int;
        final hours = map['hours_per_week'] as int;
        duplicatedInputs[subjectId] = hours;
      }

      state = state.copyWith(workspaceHours: duplicatedInputs, generationError: null);
    } catch (e) {
      state = state.copyWith(generationError: "Failed to duplicate timetable: $e");
    }
  }

  // Select a history record to view its timetables
  Future<void> selectHistoryRecord(HistoryRecord? record) async {
    if (record == null) {
      state = state.copyWith(activeHistoryRecord: null, activeSlots: []);
      return;
    }

    try {
      final db = await _dbHelper.database;
      
      // Query slots joining subjects and teachers
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          ts.*,
          s.course_code, s.course_title, s.year, s.semester, s.subject_type,
          s.faculty1_id, s.faculty2_id, s.faculty3_id,
          t1.name AS faculty1_name,
          t2.name AS faculty2_name,
          t3.name AS faculty3_name
        FROM timetable_slots ts
        LEFT JOIN subjects s ON ts.subject_id = s.id
        LEFT JOIN teachers t1 ON s.faculty1_id = t1.id
        LEFT JOIN teachers t2 ON s.faculty2_id = t2.id
        LEFT JOIN teachers t3 ON s.faculty3_id = t3.id
        WHERE ts.history_id = ?
        ORDER BY ts.year ASC, ts.day ASC, ts.period ASC
      ''', [record.id]);

      final slots = maps.map((map) {
        Subject? sub;
        if (map['subject_id'] != null) {
          sub = Subject.fromMap(map);
        }
        return TimetableSlot.fromMap(map, subject: sub);
      }).toList();

      state = state.copyWith(activeHistoryRecord: record, activeSlots: slots);
    } catch (e) {
      state = state.copyWith(generationError: "Failed to load timetable slots: $e");
    }
  }

  // Run the generation algorithm, save to DB, generate PDF/Excel files, and reload history
  Future<bool> generateTimetable(String timetableName) async {
    final subjects = subjectsState.value;
    if (subjects == null || subjects.isEmpty) {
      state = state.copyWith(generationError: "Please add subjects before generating a timetable.");
      return false;
    }

    state = state.copyWith(isGenerating: true, generationError: null);

    try {
      final db = await _dbHelper.database;

      // 1. Fetch all teacher records (needed for PDF/Excel grids generation)
      final List<Map<String, dynamic>> teacherMaps = await db.query('teachers', orderBy: 'name ASC');
      final allTeachers = teacherMaps.map((m) => Teacher.fromMap(m)).toList();

      // 2. Solve CSP
      final solver = SchedulerSolver(subjects: subjects, hoursPerWeek: state.workspaceHours);
      final generatedSlots = solver.solve(); // Throws SchedulerException if unsolvable

      // 3. Save generation run to History
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);
      final isoTimestamp = now.toIso8601String();

      // Preliminary PDF & Excel path values (we will overwrite/fill them in shortly)
      final tempRecord = HistoryRecord(
        name: timetableName,
        dateGenerated: dateStr,
        timeGenerated: timeStr,
        createdTimestamp: isoTimestamp,
        pdfPath: '',
        excelPath: '',
      );

      final historyId = await db.insert('history_records', tempRecord.toMap());

      // Save timetable inputs
      await db.transaction((txn) async {
        for (final subject in subjects) {
          final hours = state.workspaceHours[subject.id] ?? 0;
          await txn.insert('timetable_inputs', {
            'history_id': historyId,
            'subject_id': subject.id,
            'hours_per_week': hours,
          });
        }

        // Save generated slots
        for (final slot in generatedSlots) {
          await txn.insert('timetable_slots', {
            'history_id': historyId,
            'year': slot.year,
            'day': slot.day,
            'period': slot.period,
            'subject_id': slot.subjectId,
          });
        }
      });

      // Re-query slots with resolved subjects to pass to generators
      final List<Map<String, dynamic>> slotMaps = await db.rawQuery('''
        SELECT 
          ts.*,
          s.course_code, s.course_title, s.year, s.semester, s.subject_type,
          s.faculty1_id, s.faculty2_id, s.faculty3_id,
          t1.name AS faculty1_name,
          t2.name AS faculty2_name,
          t3.name AS faculty3_name
        FROM timetable_slots ts
        LEFT JOIN subjects s ON ts.subject_id = s.id
        LEFT JOIN teachers t1 ON s.faculty1_id = t1.id
        LEFT JOIN teachers t2 ON s.faculty2_id = t2.id
        LEFT JOIN teachers t3 ON s.faculty3_id = t3.id
        WHERE ts.history_id = ?
      ''', [historyId]);

      final resolvedSlots = slotMaps.map((map) {
        Subject? sub;
        if (map['subject_id'] != null) {
          sub = Subject.fromMap(map);
        }
        return TimetableSlot.fromMap(map, subject: sub);
      }).toList();

      // 4. Generate and save PDF & Excel files
      final pdfPath = await PdfGenerator.generate(
        timetableName: timetableName,
        dateStr: dateStr,
        slots: resolvedSlots,
        allSubjects: subjects,
        allTeachers: allTeachers,
      );

      final excelPath = await ExcelGenerator.generate(
        timetableName: timetableName,
        dateStr: dateStr,
        slots: resolvedSlots,
        allSubjects: subjects,
        allTeachers: allTeachers,
      );

      // 5. Update history record with file paths
      await db.update(
        'history_records',
        {
          'pdf_path': pdfPath,
          'excel_path': excelPath,
        },
        where: 'id = ?',
        whereArgs: [historyId],
      );

      // Refresh state
      await loadHistory();
      final finalRecord = HistoryRecord(
        id: historyId,
        name: timetableName,
        dateGenerated: dateStr,
        timeGenerated: timeStr,
        createdTimestamp: isoTimestamp,
        pdfPath: pdfPath,
        excelPath: excelPath,
      );
      await selectHistoryRecord(finalRecord);

      state = state.copyWith(isGenerating: false, generationError: null);
      return true;
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        generationError: e.toString().replaceFirst("Exception: ", ""),
      );
      return false;
    }
  }

  // Deletes a history record and its generated PDF/Excel files on disk
  Future<void> deleteHistoryRecord(int id) async {
    try {
      final db = await _dbHelper.database;
      
      // Get file paths to delete files off disk
      final List<Map<String, dynamic>> records = await db.query(
        'history_records',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (records.isNotEmpty) {
        final pdfPath = records.first['pdf_path'] as String;
        final excelPath = records.first['excel_path'] as String;

        try {
          final pdfFile = File(pdfPath);
          if (await pdfFile.exists()) await pdfFile.delete();
        } catch (_) {}

        try {
          final excelFile = File(excelPath);
          if (await excelFile.exists()) await excelFile.delete();
        } catch (_) {}
      }

      await db.delete('history_records', where: 'id = ?', whereArgs: [id]);
      
      if (state.activeHistoryRecord?.id == id) {
        state = state.copyWith(activeHistoryRecord: null, activeSlots: []);
      }

      await loadHistory();
    } catch (e) {
      state = state.copyWith(generationError: "Failed to delete history record: $e");
    }
  }
}
