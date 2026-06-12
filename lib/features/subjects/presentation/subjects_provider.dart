import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart';
import '../../../../core/db/db_helper.dart';
import '../domain/subject.dart';
import '../../teachers/presentation/teachers_provider.dart';

final subjectsProvider = StateNotifierProvider<SubjectsNotifier, AsyncValue<List<Subject>>>((ref) {
  final teachersNotifier = ref.watch(teachersProvider.notifier);
  return SubjectsNotifier(teachersNotifier);
});

class SubjectsNotifier extends StateNotifier<AsyncValue<List<Subject>>> {
  final TeachersNotifier teachersNotifier;
  SubjectsNotifier(this.teachersNotifier) : super(const AsyncValue.loading()) {
    loadSubjects();
  }

  final _dbHelper = DbHelper();

  Future<void> loadSubjects() async {
    state = const AsyncValue.loading();
    try {
      final db = await _dbHelper.database;
      
      // Query with joins to get faculty names
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          s.*, 
          t1.name AS faculty1_name,
          t2.name AS faculty2_name,
          t3.name AS faculty3_name
        FROM subjects s
        JOIN teachers t1 ON s.faculty1_id = t1.id
        LEFT JOIN teachers t2 ON s.faculty2_id = t2.id
        LEFT JOIN teachers t3 ON s.faculty3_id = t3.id
        ORDER BY s.year ASC, s.course_code ASC
      ''');
      
      final list = maps.map((map) => Subject.fromMap(map)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addSubject(Subject subject) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('subjects', subject.toMap());
      await loadSubjects();
    } catch (e) {
      throw Exception("Failed to add subject (code may already exist): $e");
    }
  }

  Future<void> updateSubject(Subject subject) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'subjects',
        subject.toMap(),
        where: 'id = ?',
        whereArgs: [subject.id],
      );
      await loadSubjects();
    } catch (e) {
      throw Exception("Failed to update subject: $e");
    }
  }

  Future<void> deleteSubject(int id) async {
    try {
      final db = await _dbHelper.database;
      
      // Delete associated inputs & slots via cascade
      await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
      await loadSubjects();
    } catch (e) {
      throw Exception("Failed to delete subject: $e");
    }
  }

  // Parse Excel subjects:
  // Column 0: Course Code
  // Column 1: Course Title
  // Column 2: Year (1..4)
  // Column 3: Semester (1..8)
  // Column 4: Subject Type (Theory / Lab / Project / Additional)
  // Column 5: Faculty 1 Name
  // Column 6: Faculty 2 Name (optional)
  // Column 7: Faculty 3 Name (optional)
  Future<int> importFromExcel(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception("File does not exist");
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final db = await _dbHelper.database;
      int importedCount = 0;

      await db.transaction((txn) async {
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet == null) continue;

          for (int r = 1; r < sheet.maxRows; r++) {
            final row = sheet.rows[r];
            if (row.isEmpty) continue;

            final codeVal = row[0]?.value;
            final titleVal = row.length > 1 ? row[1]?.value : null;
            final yearVal = row.length > 2 ? row[2]?.value : null;
            final semVal = row.length > 3 ? row[3]?.value : null;
            final typeVal = row.length > 4 ? row[4]?.value : null;
            final fac1Val = row.length > 5 ? row[5]?.value : null;
            final fac2Val = row.length > 6 ? row[6]?.value : null;
            final fac3Val = row.length > 7 ? row[7]?.value : null;

            if (codeVal != null && titleVal != null && yearVal != null && semVal != null && typeVal != null && fac1Val != null) {
              final String code = codeVal.toString().trim();
              final String title = titleVal.toString().trim();
              final int year = int.tryParse(yearVal.toString()) ?? 1;
              final int sem = int.tryParse(semVal.toString()) ?? 1;
              final String typeRaw = typeVal.toString().trim();
              final String type = _normalizeSubjectType(typeRaw);
              final String fac1Name = fac1Val.toString().trim();
              final String fac2Name = fac2Val?.toString().trim() ?? "";
              final String fac3Name = fac3Val?.toString().trim() ?? "";

              if (code.isNotEmpty && title.isNotEmpty && fac1Name.isNotEmpty) {
                // 1. Resolve or create Faculty 1
                final int fac1Id = await _getOrCreateTeacherId(txn, fac1Name);
                
                // 2. Resolve or create Faculty 2
                int? fac2Id;
                if (fac2Name.isNotEmpty) {
                  fac2Id = await _getOrCreateTeacherId(txn, fac2Name);
                }

                // 3. Resolve or create Faculty 3
                int? fac3Id;
                if (fac3Name.isNotEmpty) {
                  fac3Id = await _getOrCreateTeacherId(txn, fac3Name);
                }

                // Check if subject code already exists
                final List<Map<String, dynamic>> existing = await txn.query(
                  'subjects',
                  where: 'course_code = ?',
                  whereArgs: [code],
                  limit: 1,
                );

                if (existing.isEmpty) {
                  await txn.insert('subjects', {
                    'course_code': code,
                    'course_title': title,
                    'year': year,
                    'semester': sem,
                    'subject_type': type,
                    'faculty1_id': fac1Id,
                    'faculty2_id': fac2Id,
                    'faculty3_id': fac3Id,
                  });
                  importedCount++;
                } else {
                  // Update it
                  await txn.update(
                    'subjects',
                    {
                      'course_title': title,
                      'year': year,
                      'semester': sem,
                      'subject_type': type,
                      'faculty1_id': fac1Id,
                      'faculty2_id': fac2Id,
                      'faculty3_id': fac3Id,
                    },
                    where: 'course_code = ?',
                    whereArgs: [code],
                  );
                  importedCount++;
                }
              }
            }
          }
        }
      });

      if (importedCount > 0) {
        await teachersNotifier.loadTeachers(); // Reload teachers list in case new ones were added
        await loadSubjects();
      }
      return importedCount;
    } catch (e) {
      throw Exception("Excel Import Failed: $e");
    }
  }

  String _normalizeSubjectType(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == 'lab') return 'Lab';
    if (lower == 'project') return 'Project';
    if (lower == 'additional') return 'Additional';
    return 'Theory';
  }

  Future<int> _getOrCreateTeacherId(dynamic txn, String name) async {
    final List<Map<String, dynamic>> existing = await txn.query(
      'teachers',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    } else {
      // Create a default new teacher
      final id = await txn.insert('teachers', {
        'name': name,
        'designation': 'Assistant Professor', // Default designation
      });
      return id;
    }
  }
}
