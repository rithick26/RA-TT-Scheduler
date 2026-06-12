import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'timetable_provider.dart';
import '../../teachers/presentation/teachers_provider.dart';
import '../../teachers/domain/teacher.dart';
import '../domain/timetable_models.dart';

class ViewTimetableTab extends ConsumerStatefulWidget {
  const ViewTimetableTab({super.key});

  @override
  ConsumerState<ViewTimetableTab> createState() => _ViewTimetableTabState();
}

class _ViewTimetableTabState extends ConsumerState<ViewTimetableTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Teacher? _selectedFaculty;

  static const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  static const periods = [
    'Period 1',
    'Period 2',
    'Period 3',
    'Period 4',
    'Period 5',
    'Period 6',
    'Period 7',
    'Period 8',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await OpenFilex.open(path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Could not open file: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("File not found! It may have been deleted."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printPdf(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        await Printing.layoutPdf(
          onLayout: (format) => bytes,
          name: pBasename(path),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Printing error: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PDF File not found!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String pBasename(String path) {
    return path.split(Platform.isWindows ? '\\' : '/').last;
  }

  @override
  Widget build(BuildContext context) {
    final timetableState = ref.watch(timetableProvider);
    final teachersState = ref.watch(teachersProvider);
    final theme = Theme.of(context);

    final record = timetableState.activeHistoryRecord;
    final slots = timetableState.activeSlots;

    if (record == null || slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grid_off_rounded,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              "No timetable active",
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Generate a new timetable or load a generated one from the 'History' tab.",
            ),
          ],
        ),
      );
    }

    // Resolve faculties list
    final List<Teacher> teachers = teachersState.maybeWhen(
      data: (list) => list,
      orElse: () => [],
    );

    if (_selectedFaculty == null && teachers.isNotEmpty) {
      _selectedFaculty = teachers.first;
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Column(
          children: [
            // Header actions panel
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Generated: ${record.dateGenerated} at ${record.timeGenerated}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () => _printPdf(record.pdfPath),
                    icon: const Icon(Icons.print_rounded),
                    tooltip: "Print Timetable",
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openFile(record.pdfPath),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text("Open PDF"),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openFile(record.excelPath),
                    icon: const Icon(Icons.table_view_rounded),
                    label: const Text("Open Excel"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: "Year 1"),
                Tab(text: "Year 2"),
                Tab(text: "Year 3"),
                Tab(text: "Year 4"),
                Tab(text: "Faculty Timetables"),
                Tab(text: "Master Timetable"),
              ],
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildYearGrid(slots, 1, theme),
          _buildYearGrid(slots, 2, theme),
          _buildYearGrid(slots, 3, theme),
          _buildYearGrid(slots, 4, theme),
          _buildFacultyGrid(slots, teachers, theme),
          _buildMasterGrid(slots, theme),
        ],
      ),
    );
  }

  Widget _buildYearGrid(
    List<TimetableSlot> allSlots,
    int year,
    ThemeData theme,
  ) {
    final yearSlots = allSlots.where((s) => s.year == year).toList();

    // Day (0..4) -> Period (0..7) -> Slot
    final grid = List.generate(5, (_) => List<TimetableSlot?>.filled(8, null));
    for (final s in yearSlots) {
      if (s.day < 5 && s.period < 8) {
        grid[s.day][s.period] = s;
      }
    }

    return _buildGridTable(
      grid: grid,
      theme: theme,
      cellBuilder: (slot) {
        if (slot?.subject == null)
          return const Text("-", style: TextStyle(color: Colors.grey));
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slot!.subject!.courseCode,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              slot.subject!.courseTitle,
              style: const TextStyle(
                fontSize: 10,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
            Text(
              slot.subject!.faculty1Name ?? "",
              style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFacultyGrid(
    List<TimetableSlot> allSlots,
    List<Teacher> teachers,
    ThemeData theme,
  ) {
    if (teachers.isEmpty) {
      return const Center(child: Text("No teachers registered."));
    }

    // Filter slots where selected faculty is assigned
    final facultySlots = allSlots
        .where(
          (s) =>
              s.subject != null &&
              (s.subject!.faculty1Id == _selectedFaculty?.id ||
                  s.subject!.faculty2Id == _selectedFaculty?.id ||
                  s.subject!.faculty3Id == _selectedFaculty?.id),
        )
        .toList();

    // Day (0..4) -> Period (0..7) -> Slot
    final grid = List.generate(5, (_) => List<TimetableSlot?>.filled(8, null));
    for (final s in facultySlots) {
      grid[s.day][s.period] = s;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Select Faculty: ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              DropdownButton<Teacher>(
                value: _selectedFaculty,
                items: teachers.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text("${t.name} (${t.designation})"),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedFaculty = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildGridTable(
              grid: grid,
              theme: theme,
              cellBuilder: (slot) {
                if (slot?.subject == null)
                  return const Text("-", style: TextStyle(color: Colors.grey));
                final roman = _getRomanRoman(slot!.year);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$roman Year",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      slot.subject!.courseCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      slot.subject!.courseTitle,
                      style: const TextStyle(
                        fontSize: 9,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterGrid(List<TimetableSlot> allSlots, ThemeData theme) {
    // 5x8 grid where cells contain multiple entries
    final grid = List.generate(
      5,
      (_) => List<List<TimetableSlot>>.generate(8, (_) => []),
    );
    for (final s in allSlots) {
      if (s.subject != null) {
        grid[s.day][s.period].add(s);
      }
    }

    return _buildGridTable(
      grid: grid,
      theme: theme,
      cellBuilder: (concurrentSlots) {
        final list = concurrentSlots as List<TimetableSlot>;
        if (list.isEmpty)
          return const Text("-", style: TextStyle(color: Colors.grey));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          itemBuilder: (context, idx) {
            final s = list[idx];
            final roman = _getRomanRoman(s.year);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 2.0),
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "$roman - ${s.subject!.courseCode}",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            );
          },
        );
      },
    );
  }

  // Base Grid table renderer
  Widget _buildGridTable({
    required List<List<dynamic>> grid,
    required ThemeData theme,
    required Widget Function(dynamic) cellBuilder,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Table(
        border: TableBorder.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
        columnWidths: {
          0: FixedColumnWidth(100), // Day column
          for (int i = 1; i <= 8; i++) i: FlexColumnWidth(1),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant),
            children: [
              const TableCell(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      "Day / Period",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              ...periods.map(
                (p) => TableCell(
                  child: Center(
                    child: Text(
                      p,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Data Rows (Days)
          ...List.generate(5, (dIdx) {
            final dayName = days[dIdx];
            return TableRow(
              children: [
                // Day Label
                TableCell(
                  child: Container(
                    height: 90, // Fix cell height for uniform grids
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                    alignment: Alignment.center,
                    child: Text(
                      dayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                // Periods
                ...List.generate(8, (pIdx) {
                  final data = grid[dIdx][pIdx];
                  return TableCell(
                    child: Container(
                      height: 90,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(4.0),
                      child: cellBuilder(data),
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _getRomanRoman(int year) {
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
