import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import '../../subjects/domain/subject.dart';
import '../../teachers/domain/teacher.dart';
import 'timetable_models.dart';

class ExcelGenerator {
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const periods = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'];

  static Future<String> generate({
    required String timetableName,
    required String dateStr,
    required List<TimetableSlot> slots,
    required List<Subject> allSubjects,
    required List<Teacher> allTeachers,
  }) async {
    final excel = Excel.createExcel();

    // The default excel file contains a sheet named "Sheet1".
    // We will rename or use it as "Year 1 Timetable".
    excel.rename('Sheet1', 'Year 1 Timetable');

    // Create other sheets
    excel.updateCell(
      'Year 2 Timetable',
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue('Year 2'),
    );
    excel.updateCell(
      'Year 3 Timetable',
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue('Year 3'),
    );
    excel.updateCell(
      'Year 4 Timetable',
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue('Year 4'),
    );
    excel.updateCell(
      'Faculty Timetables',
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue('Faculty'),
    );
    excel.updateCell(
      'Master Timetable',
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      TextCellValue('Master'),
    );

    // Group slots by Year
    final slotsByYear = <int, List<TimetableSlot>>{};
    for (int y = 1; y <= 4; y++) {
      slotsByYear[y] = slots.where((s) => s.year == y).toList();
    }

    // 1. Populate Year 1-4 Sheets
    for (int y = 1; y <= 4; y++) {
      final sheetName = 'Year $y Timetable';
      final sheetSlots = slotsByYear[y] ?? [];
      _writeTimetableGrid(
        excel: excel,
        sheetName: sheetName,
        title: "YEAR $y TIMETABLE - $timetableName",
        dateStr: dateStr,
        slots: sheetSlots,
        cellTextResolver: (slot) => slot.subject?.courseCode ?? "-",
      );
    }

    // 2. Populate Faculty Timetables Sheet (Appended sequentially)
    final facultySheet = 'Faculty Timetables';
    _writeFacultyTimetables(
      excel: excel,
      sheetName: facultySheet,
      timetableName: timetableName,
      dateStr: dateStr,
      teachers: allTeachers,
      slots: slots,
    );

    // 3. Populate Master Timetable Sheet
    final masterSheet = 'Master Timetable';
    _writeMasterTimetableGrid(
      excel: excel,
      sheetName: masterSheet,
      title: "MASTER TIMETABLE - $timetableName",
      dateStr: dateStr,
      slots: slots,
    );

    // Save Excel file
    final appSupportDir = await getApplicationSupportDirectory();
    final excelDir = Directory(
      p.join(appSupportDir.path, 'TimetableScheduler', 'Excel'),
    );
    if (!await excelDir.exists()) {
      await excelDir.create(recursive: true);
    }

    // Sanitize filename
    final sanitizedName = timetableName.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final filePath = p.join(excelDir.path, '${sanitizedName}.xlsx');
    final file = File(filePath);
    await file.writeAsBytes(excel.save()!);

    return filePath;
  }

  static void _writeTimetableGrid({
    required Excel excel,
    required String sheetName,
    required String title,
    required String dateStr,
    required List<TimetableSlot> slots,
    required String Function(TimetableSlot) cellTextResolver,
    int startRow = 0,
  }) {
    final sheet = excel[sheetName];

    // Write Headers
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow))
        .value = TextCellValue(
      "SRI RAMAKRISHNA ENGINEERING COLLEGE",
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 1),
        )
        .value = TextCellValue(
      "DEPARTMENT OF ROBOTICS AND AUTOMATION",
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: startRow + 2),
        )
        .value = TextCellValue(
      "$title (Generated: $dateStr)",
    );

    // Table Header Row
    final headerRowIdx = startRow + 4;
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRowIdx),
        )
        .value = TextCellValue(
      "Day / Period",
    );
    for (int pIdx = 0; pIdx < periods.length; pIdx++) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: pIdx + 1,
              rowIndex: headerRowIdx,
            ),
          )
          .value = TextCellValue(
        periods[pIdx],
      );
    }

    // Reconstruct 5x8 grid
    final gridData = List.generate(5, (_) => List<String>.filled(8, "-"));
    for (final slot in slots) {
      if (slot.day < 5 && slot.period < 8) {
        gridData[slot.day][slot.period] = cellTextResolver(slot);
      }
    }

    // Write Day Rows
    for (int d = 0; d < 5; d++) {
      final rowIdx = headerRowIdx + 1 + d;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
          .value = TextCellValue(
        days[d],
      );
      for (int p = 0; p < 8; p++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: p + 1, rowIndex: rowIdx),
            )
            .value = TextCellValue(
          gridData[d][p],
        );
      }
    }
  }

  static void _writeMasterTimetableGrid({
    required Excel excel,
    required String sheetName,
    required String title,
    required String dateStr,
    required List<TimetableSlot> slots,
  }) {
    final sheet = excel[sheetName];

    // Write Headers
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue("SRI RAMAKRISHNA ENGINEERING COLLEGE");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue("DEPARTMENT OF ROBOTICS AND AUTOMATION");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).value =
        TextCellValue("$title (Generated: $dateStr)");

    // Table Header Row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4)).value =
        TextCellValue("Day / Period");
    for (int pIdx = 0; pIdx < periods.length; pIdx++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: pIdx + 1, rowIndex: 4))
          .value = TextCellValue(
        periods[pIdx],
      );
    }

    // Populate Master Cells
    for (int d = 0; d < 5; d++) {
      final rowIdx = 5 + d;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
          .value = TextCellValue(
        days[d],
      );

      for (int p = 0; p < 8; p++) {
        final day = d;
        final period = p;
        final concurrent = slots
            .where((s) => s.day == day && s.period == period)
            .toList();

        final cellTexts = <String>[];
        for (final c in concurrent) {
          if (c.subject != null) {
            final roman = _getRomanNumeral(c.year);
            cellTexts.add("$roman-${c.subject!.courseCode}");
          }
        }
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: p + 1, rowIndex: rowIdx),
            )
            .value = TextCellValue(
          cellTexts.isEmpty ? "-" : cellTexts.join(", "),
        );
      }
    }
  }

  static void _writeFacultyTimetables({
    required Excel excel,
    required String sheetName,
    required String timetableName,
    required String dateStr,
    required List<Teacher> teachers,
    required List<TimetableSlot> slots,
  }) {
    final sheet = excel[sheetName];

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue("SRI RAMAKRISHNA ENGINEERING COLLEGE");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue("DEPARTMENT OF ROBOTICS AND AUTOMATION");
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
        .value = TextCellValue(
      "FACULTY TIMETABLES - $timetableName (Generated: $dateStr)",
    );

    int currentStartRow = 5;

    for (final teacher in teachers) {
      sheet
          .cell(
            CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentStartRow,
            ),
          )
          .value = TextCellValue(
        "Faculty: ${teacher.name} (${teacher.designation})",
      );

      // Header row
      final headerRowIdx = currentStartRow + 1;
      sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: headerRowIdx),
          )
          .value = TextCellValue(
        "Day / Period",
      );
      for (int pIdx = 0; pIdx < periods.length; pIdx++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: pIdx + 1,
                rowIndex: headerRowIdx,
              ),
            )
            .value = TextCellValue(
          periods[pIdx],
        );
      }

      // Reconstruct grid for this teacher
      final gridData = List.generate(5, (_) => List<String>.filled(8, "-"));
      for (final slot in slots) {
        if (slot.subject != null &&
            (slot.subject!.faculty1Id == teacher.id ||
                slot.subject!.faculty2Id == teacher.id ||
                slot.subject!.faculty3Id == teacher.id)) {
          final roman = _getRomanNumeral(slot.year);
          gridData[slot.day][slot.period] =
              "$roman Yr - ${slot.subject!.courseCode}";
        }
      }

      // Write Day Rows
      for (int d = 0; d < 5; d++) {
        final rowIdx = headerRowIdx + 1 + d;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
            .value = TextCellValue(
          days[d],
        );
        for (int p = 0; p < 8; p++) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: p + 1,
                  rowIndex: rowIdx,
                ),
              )
              .value = TextCellValue(
            gridData[d][p],
          );
        }
      }

      // Advance start row for next teacher grid (5 days + 1 header + 1 title + 2 empty rows = 9 rows)
      currentStartRow += 9;
    }
  }

  static String _getRomanNumeral(int year) {
    switch (year) {
      case 1:
        return "I";
      case 2:
        return "II";
      case 3:
        return "III";
      case 4:
        return "IV";
      default:
        return year.toString();
    }
  }
}
