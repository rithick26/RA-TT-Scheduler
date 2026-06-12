import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../domain/subject.dart';
import 'subjects_provider.dart';
import '../../teachers/presentation/teachers_provider.dart';
import '../../teachers/domain/teacher.dart';

class SubjectsTab extends ConsumerStatefulWidget {
  const SubjectsTab({super.key});

  @override
  ConsumerState<SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends ConsumerState<SubjectsTab> {
  final List<bool> _isExpanded = [true, false, false, false];

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isFixed = false;
  List<String> _lockedSlots = [];
  int _selectedYear = 1;
  int _selectedSemester = 1;
  String _selectedType = "Theory";
  int? _faculty1Id;
  int? _faculty2Id;
  int? _faculty3Id;

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _showAddEditDialog([Subject? subject, int? presetYear]) {
    final isEditing = subject != null;
    final teachersState = ref.read(teachersProvider);

    final List<Teacher> teachers = teachersState.maybeWhen(
      data: (list) => list,
      orElse: () => [],
    );

    if (teachers.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("No Teachers Available"),
          content: const Text(
            "You must add teachers first before adding subjects.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    if (isEditing) {
      _codeController.text = subject.courseCode;
      _titleController.text = subject.courseTitle;
      _selectedYear = subject.year;
      _selectedSemester = subject.semester;
      _selectedType = subject.subjectType;
      _faculty1Id = teachers.any((t) => t.id == subject.faculty1Id)
          ? subject.faculty1Id
          : teachers.first.id;
      _faculty2Id =
          subject.faculty2Id != null &&
              teachers.any((t) => t.id == subject.faculty2Id)
          ? subject.faculty2Id
          : null;
      _faculty3Id =
          subject.faculty3Id != null &&
              teachers.any((t) => t.id == subject.faculty3Id)
          ? subject.faculty3Id
          : null;
      _isFixed = subject.isFixed;
      _lockedSlots = List<String>.from(subject.lockedSlots ?? <String>[]);
    } else {
      _codeController.clear();
      _titleController.clear();
      _selectedYear = presetYear ?? 1;
      _selectedSemester =
          (_selectedYear * 2) - 1; // Default odd semester for selected year
      _selectedType = "Theory";
      _faculty1Id = teachers.isNotEmpty ? teachers.first.id : null;
      _faculty2Id = null;
      _faculty3Id = null;
      _isFixed = false;
      _lockedSlots = [];
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? "Edit Subject" : "Add Subject"),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: "Course Code",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty)
                        return "Enter course code";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Course Title",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty)
                        return "Enter course title";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedYear,
                          decoration: const InputDecoration(
                            labelText: "Year",
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text("Year 1")),
                            DropdownMenuItem(value: 2, child: Text("Year 2")),
                            DropdownMenuItem(value: 3, child: Text("Year 3")),
                            DropdownMenuItem(value: 4, child: Text("Year 4")),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                _selectedYear = val;
                                // Auto adjust semester dropdown options
                                _selectedSemester = (_selectedYear * 2) - 1;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedSemester,
                          decoration: const InputDecoration(
                            labelText: "Semester",
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(2, (index) {
                            final semNum = (_selectedYear * 2) - 1 + index;
                            return DropdownMenuItem(
                              value: semNum,
                              child: Text("Semester $semNum"),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                _selectedSemester = val;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: "Subject Type",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: "Theory", child: Text("Theory")),
                      DropdownMenuItem(
                        value: "Lab",
                        child: Text("Lab (Continuous block)"),
                      ),
                      DropdownMenuItem(
                        value: "Project",
                        child: Text("Project"),
                      ),
                      DropdownMenuItem(
                        value: "Additional",
                        child: Text("Additional"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          _selectedType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  CheckboxListTile(
                    value: _isFixed,
                    title: const Text("Fixed Classes"),
                    subtitle: const Text("Lock specific periods in timetable"),
                    onChanged: (value) {
                      setDialogState(() {
                        _isFixed = value ?? false;

                        if (!_isFixed) {
                          _lockedSlots.clear();
                        }
                      });
                    },
                  ),
                  if (_isFixed)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Select Fixed Periods",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(40, (index) {
                            final day = index ~/ 8;
                            final period = index % 8;

                            final slot = "${day}_$period";

                            final selected = _lockedSlots.contains(slot);

                            return FilterChip(
                              label: Text("D${day + 1}-P${period + 1}"),
                              selected: selected,
                              onSelected: (value) {
                                setDialogState(() {
                                  if (value) {
                                    _lockedSlots.add(slot);
                                  } else {
                                    _lockedSlots.remove(slot);
                                  }
                                });
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _faculty1Id,
                    decoration: const InputDecoration(
                      labelText: "Faculty 1 (Required)",
                      border: OutlineInputBorder(),
                    ),
                    items: teachers.map((t) {
                      return DropdownMenuItem(value: t.id, child: Text(t.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          _faculty1Id = val;
                        });
                      }
                    },
                    validator: (val) =>
                        val == null ? "Select primary faculty" : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _faculty2Id,
                    decoration: const InputDecoration(
                      labelText: "Faculty 2 (Optional)",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text("- None -"),
                      ),
                      ...teachers.map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        _faculty2Id = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _faculty3Id,
                    decoration: const InputDecoration(
                      labelText: "Faculty 3 (Optional)",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text("- None -"),
                      ),
                      ...teachers.map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        _faculty3Id = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  if (_isFixed && _lockedSlots.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Select at least one fixed period'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final notifier = ref.read(subjectsProvider.notifier);
                  final newSubject = Subject(
                    id: subject?.id,
                    courseCode: _codeController.text.toUpperCase().trim(),
                    courseTitle: _titleController.text.trim(),
                    year: _selectedYear,
                    semester: _selectedSemester,
                    subjectType: _selectedType,
                    faculty1Id: _faculty1Id!,
                    faculty2Id: _faculty2Id,
                    faculty3Id: _faculty3Id,
                    isFixed: _isFixed,
                    lockedSlots: _lockedSlots,
                  );

                  try {
                    if (isEditing) {
                      await notifier.updateSubject(newSubject);
                    } else {
                      await notifier.addSubject(newSubject);
                    }
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSubject(Subject subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Subject?"),
        content: Text(
          "Are you sure you want to delete ${subject.courseCode} - ${subject.courseTitle}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(subjectsProvider.notifier).deleteSubject(subject.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${subject.courseCode} deleted!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _importExcel() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      dialogTitle: 'Select Subjects Excel File',
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final count = await ref
            .read(subjectsProvider.notifier)
            .importFromExcel(path);

        if (!mounted) return;
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported/updated $count subjects!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsState = ref.watch(subjectsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Organize subjects by academic year",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _importExcel,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text("Import from Excel"),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: subjectsState.when(
                data: (subjects) {
                  return SingleChildScrollView(
                    child: ExpansionPanelList(
                      expansionCallback: (panelIndex, isExpanded) {
                        setState(() {
                          _isExpanded[panelIndex] = !isExpanded;
                        });
                      },
                      elevation: 1,
                      children: List.generate(4, (index) {
                        final year = index + 1;
                        final yearSubjects = subjects
                            .where((s) => s.year == year)
                            .toList();

                        return ExpansionPanel(
                          headerBuilder: (context, isExpanded) => ListTile(
                            title: Text(
                              "Year $year",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              "${yearSubjects.length} subjects registered",
                            ),
                          ),
                          isExpanded: _isExpanded[index],
                          body: Padding(
                            padding: const EdgeInsets.only(
                              left: 16.0,
                              right: 16.0,
                              bottom: 16.0,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showAddEditDialog(null, year),
                                      icon: const Icon(Icons.add),
                                      label: Text("Add Subject (Year $year)"),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (yearSubjects.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      "No subjects registered for Year $year.",
                                      style: TextStyle(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: yearSubjects.length,
                                    separatorBuilder: (c, i) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, sIndex) {
                                      final subject = yearSubjects[sIndex];
                                      return ListTile(
                                        title: Row(
                                          children: [
                                            Text(
                                              subject.courseCode,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(subject.courseTitle),

                                            if (subject.isFixed)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: Icon(
                                                  Icons.lock,
                                                  size: 18,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            const SizedBox(width: 12),
                                            Chip(
                                              label: Text(
                                                subject.subjectType,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              backgroundColor:
                                                  subject.subjectType == 'Lab'
                                                  ? Colors.amber.shade100
                                                  : theme
                                                        .colorScheme
                                                        .primaryContainer,
                                            ),
                                          ],
                                        ),
                                        subtitle: Text(
                                          "Sem: ${subject.semester} | Faculty: ${subject.facultyNames.join(', ')}",
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              onPressed: () =>
                                                  _showAddEditDialog(subject),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  _deleteSubject(subject),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
