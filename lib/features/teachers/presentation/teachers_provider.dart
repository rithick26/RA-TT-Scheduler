import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart';
import '../../../../core/db/db_helper.dart';
import '../domain/teacher.dart';

final teachersProvider = StateNotifierProvider<TeachersNotifier, AsyncValue<List<Teacher>>>((ref) {
  return TeachersNotifier();
});

class TeachersNotifier extends StateNotifier<AsyncValue<List<Teacher>>> {
  TeachersNotifier() : super(const AsyncValue.loading()) {
    loadTeachers();
  }

  final _dbHelper = DbHelper();

  Future<void> loadTeachers() async {
    state = const AsyncValue.loading();
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('teachers', orderBy: 'name ASC');
      final list = maps.map((map) => Teacher.fromMap(map)).toList();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addTeacher(String name, String designation) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('teachers', {
        'name': name.trim(),
        'designation': designation.trim(),
      });
      await loadTeachers();
    } catch (e) {
      throw Exception("Failed to add teacher: $e");
    }
  }

  Future<void> updateTeacher(Teacher teacher) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'teachers',
        teacher.toMap(),
        where: 'id = ?',
        whereArgs: [teacher.id],
      );
      await loadTeachers();
    } catch (e) {
      throw Exception("Failed to update teacher: $e");
    }
  }

  // Deletes teacher after checking if they are assigned to any subject
  Future<void> deleteTeacher(int id) async {
    try {
      final db = await _dbHelper.database;
      
      // Check if referenced in subjects (faculty1_id, faculty2_id, faculty3_id)
      final List<Map<String, dynamic>> references = await db.query(
        'subjects',
        where: 'faculty1_id = ? OR faculty2_id = ? OR faculty3_id = ?',
        whereArgs: [id, id, id],
        limit: 1,
      );

      if (references.isNotEmpty) {
        throw Exception(
          "Cannot delete teacher because they are currently assigned to a subject. "
          "Please remove this teacher from all subjects first."
        );
      }

      await db.delete('teachers', where: 'id = ?', whereArgs: [id]);
      await loadTeachers();
    } catch (e) {
      rethrow;
    }
  }

  // Imports teachers from an Excel file
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

          // Expect column headers: Teacher Name, Designation
          for (int r = 1; r < sheet.maxRows; r++) {
            final row = sheet.rows[r];
            if (row.isEmpty) continue;

            final nameVal = row[0]?.value;
            final desigVal = row.length > 1 ? row[1]?.value : null;

            if (nameVal != null && desigVal != null) {
              final String name = nameVal.toString().trim();
              final String designation = desigVal.toString().trim();

              if (name.isNotEmpty && designation.isNotEmpty) {
                // Check if this teacher already exists (optional, let's check by name and designation)
                final List<Map<String, dynamic>> existing = await txn.query(
                  'teachers',
                  where: 'name = ? AND designation = ?',
                  whereArgs: [name, designation],
                  limit: 1,
                );

                if (existing.isEmpty) {
                  await txn.insert('teachers', {
                    'name': name,
                    'designation': designation,
                  });
                  importedCount++;
                }
              }
            }
          }
        }
      });

      if (importedCount > 0) {
        await loadTeachers();
      }
      return importedCount;
    } catch (e) {
      throw Exception("Excel Import Failed: $e");
    }
  }
}
