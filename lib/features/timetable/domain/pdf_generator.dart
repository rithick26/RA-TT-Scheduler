import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../subjects/domain/subject.dart';
import '../../teachers/domain/teacher.dart';
import 'timetable_models.dart';

class PdfGenerator {
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const periods = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'];

  static Future<String> generate({
    required String timetableName,
    required String dateStr,
    required List<TimetableSlot> slots,
    required List<Subject> allSubjects,
    required List<Teacher> allTeachers,
  }) async {
    final pdf = pw.Document();

    // Group slots by Year
    final slotsByYear = <int, List<TimetableSlot>>{};
    for (int y = 1; y <= 4; y++) {
      slotsByYear[y] = slots.where((s) => s.year == y).toList();
    }

    // Define standard theme styles
    final titleStyle = pw.TextStyle(
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.blue900,
    );
    final subtitleStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
    );
    final headerStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = pw.TextStyle(fontSize: 9);
    final cellBoldStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    // 1. Pages for Years 1-4 Timetables
    for (int y = 1; y <= 4; y++) {
      final yearSlots = slotsByYear[y] ?? [];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  timetableName,
                  dateStr,
                  "YEAR $y TIMETABLE",
                  titleStyle,
                  subtitleStyle,
                ),
                pw.SizedBox(height: 15),
                _buildGridTable(
                  yearSlots,
                  (slot) {
                    return slot.subject?.courseCode ?? "-";
                  },
                  headerStyle,
                  cellStyle,
                  cellBoldStyle,
                ),
                pw.Spacer(),
                _buildFooter(),
              ],
            );
          },
        ),
      );
    }

    // 2. Page for Master Timetable
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(
                timetableName,
                dateStr,
                "MASTER TIMETABLE",
                titleStyle,
                subtitleStyle,
              ),
              pw.SizedBox(height: 15),
              _buildGridTable(
                slots,
                (slot) {
                  // Master cell: display concurrent courses for this slot across all years
                  final day = slot.day;
                  final period = slot.period;
                  final concurrent = slots
                      .where((s) => s.day == day && s.period == period)
                      .toList();

                  final cellTexts = <String>[];
                  for (final c in concurrent) {
                    if (c.subject != null) {
                      final roman = _getRomanNumeral(c.year);
                      cellTexts.add("$roman - ${c.subject!.courseCode}");
                    }
                  }
                  return cellTexts.isEmpty ? "-" : cellTexts.join("\n");
                },
                headerStyle,
                cellStyle,
                cellBoldStyle,
                isMaster: true,
              ),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    // 3. Pages for Faculty Timetables (Grouped to fit multiple per page or 1 per page. Let's do 2 per page for efficiency)
    for (int i = 0; i < allTeachers.length; i += 2) {
      final t1 = allTeachers[i];
      final t2 = i + 1 < allTeachers.length ? allTeachers[i + 1] : null;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  timetableName,
                  dateStr,
                  "FACULTY TIMETABLES",
                  titleStyle,
                  subtitleStyle,
                ),
                pw.SizedBox(height: 15),
                pw.Text(
                  "Faculty: ${t1.name} (${t1.designation})",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                pw.SizedBox(height: 5),
                _buildGridTable(
                  slots,
                  (slot) {
                    // Find if teacher teaches in this slot
                    final day = slot.day;
                    final period = slot.period;
                    final match = slots.firstWhere(
                      (s) =>
                          s.day == day &&
                          s.period == period &&
                          s.subject != null &&
                          (s.subject!.faculty1Id == t1.id ||
                              s.subject!.faculty2Id == t1.id ||
                              s.subject!.faculty3Id == t1.id),
                      orElse: () => TimetableSlot(
                        historyId: 0,
                        year: 0,
                        day: 0,
                        period: 0,
                      ),
                    );
                    if (match.year > 0 && match.subject != null) {
                      final roman = _getRomanNumeral(match.year);
                      return "$roman Year\n${match.subject!.courseCode}";
                    }
                    return "-";
                  },
                  headerStyle,
                  cellStyle,
                  cellBoldStyle,
                  height: 75,
                ),
                if (t2 != null) ...[
                  pw.SizedBox(height: 20),
                  pw.Text(
                    "Faculty: ${t2.name} (${t2.designation})",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  _buildGridTable(
                    slots,
                    (slot) {
                      final day = slot.day;
                      final period = slot.period;
                      final match = slots.firstWhere(
                        (s) =>
                            s.day == day &&
                            s.period == period &&
                            s.subject != null &&
                            (s.subject!.faculty1Id == t2.id ||
                                s.subject!.faculty2Id == t2.id ||
                                s.subject!.faculty3Id == t2.id),
                        orElse: () => TimetableSlot(
                          historyId: 0,
                          year: 0,
                          day: 0,
                          period: 0,
                        ),
                      );
                      if (match.year > 0 && match.subject != null) {
                        final roman = _getRomanNumeral(match.year);
                        return "$roman Year\n${match.subject!.courseCode}";
                      }
                      return "-";
                    },
                    headerStyle,
                    cellStyle,
                    cellBoldStyle,
                    height: 75,
                  ),
                ],
                pw.Spacer(),
                _buildFooter(),
              ],
            );
          },
        ),
      );
    }

    // Save PDF file
    final appSupportDir = await getApplicationSupportDirectory();
    final pdfDir = Directory(
      p.join(appSupportDir.path, 'TimetableScheduler', 'PDFs'),
    );
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    // Sanitize filename
    final sanitizedName = timetableName.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    final filePath = p.join(pdfDir.path, '${sanitizedName}.pdf');
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  static pw.Widget _buildHeader(
    String name,
    String dateStr,
    String subTitleText,
    pw.TextStyle titleStyle,
    pw.TextStyle subtitleStyle,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("SRI RAMAKRISHNA ENGINEERING COLLEGE", style: titleStyle),
            pw.Text(
              "DEPARTMENT OF ROBOTICS AND AUTOMATION",
              style: subtitleStyle,
            ),
            pw.Text(
              "Timetable: $name - $subTitleText",
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              "Date Generated: $dateStr",
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Text(
              "Version: 1.0.0",
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          "Generated via Offline Timetable Scheduler",
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.Text(
          "Created by Rithick P (Roll No: 71812310045)",
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
      ],
    );
  }

  static pw.Widget _buildGridTable(
    List<TimetableSlot> slots,
    String Function(TimetableSlot) cellTextResolver,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    pw.TextStyle cellBoldStyle, {
    bool isMaster = false,
    double height = 180,
  }) {
    // Reconstruct 5x8 grid
    final gridData = List.generate(5, (_) => List<String>.filled(8, "-"));

    if (isMaster) {
      // For master table, we receive all slots and build the cells by filtering
      for (int d = 0; d < 5; d++) {
        for (int p = 0; p < 8; p++) {
          final dummySlot = TimetableSlot(
            historyId: 0,
            year: 0,
            day: d,
            period: p,
          );
          gridData[d][p] = cellTextResolver(dummySlot);
        }
      }
    } else {
      // For single year / single faculty timetables
      for (final slot in slots) {
        if (slot.day < 5 && slot.period < 8) {
          gridData[slot.day][slot.period] = cellTextResolver(slot);
        }
      }
    }

    final tableRows = <pw.TableRow>[];

    // Header row
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blue800),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: pw.Center(
              child: pw.Text("Day / Period", style: headerStyle),
            ),
          ),
          ...periods.map(
            (p) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 8,
              ),
              child: pw.Center(child: pw.Text(p, style: headerStyle)),
            ),
          ),
        ],
      ),
    );

    // Day rows
    for (int d = 0; d < 5; d++) {
      final dayName = days[d];
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: d % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
          ),
          children: [
            // Day Label
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 4,
              ),
              child: pw.Text(dayName, style: cellBoldStyle),
            ),
            // Periods
            ...List.generate(8, (p) {
              final text = gridData[d][p];
              return pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  text,
                  style: text == "-" ? cellStyle : cellBoldStyle,
                  textAlign: pw.TextAlign.center,
                ),
              );
            }),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(80),
        for (int i = 1; i <= 8; i++) i: const pw.FlexColumnWidth(1),
      },
      children: tableRows,
    );
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
