import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'timetable_provider.dart';
import '../../subjects/presentation/subjects_provider.dart';

class CreateTimetableTab extends ConsumerStatefulWidget {
  const CreateTimetableTab({super.key});

  @override
  ConsumerState<CreateTimetableTab> createState() => _CreateTimetableTabState();
}

class _CreateTimetableTabState extends ConsumerState<CreateTimetableTab> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _triggerGeneration() async {
    // 1. Gather inputs
    final timetableState = ref.read(timetableProvider);
    final subjectsState = ref.read(subjectsProvider);
    final subjects = subjectsState.value ?? [];

    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot generate timetable: No subjects have been added yet."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Client-side Pre-Generation Validations (for instant response)
    // Check if total hours for any year exceeds 40
    for (int y = 1; y <= 4; y++) {
      final yearSubjects = subjects.where((s) => s.year == y).toList();
      final totalHours = yearSubjects.fold<int>(0, (sum, s) => sum + (timetableState.workspaceHours[s.id!] ?? 0));
      if (totalHours > 40) {
        _showErrorDialog("Year $y requires $totalHours hours in total, but only 40 weekly slots are available. Please reduce the hours.");
        return;
      }
    }

    // Check if any teacher workload exceeds 40 hours
    final facultyHours = <int, int>{};
    final facultyNames = <int, String>{};
    for (final s in subjects) {
      final hours = timetableState.workspaceHours[s.id!] ?? 0;
      if (hours == 0) continue;

      facultyHours[s.faculty1Id] = (facultyHours[s.faculty1Id] ?? 0) + hours;
      if (s.faculty1Name != null) facultyNames[s.faculty1Id] = s.faculty1Name!;

      if (s.faculty2Id != null) {
        facultyHours[s.faculty2Id!] = (facultyHours[s.faculty2Id!] ?? 0) + hours;
        if (s.faculty2Name != null) facultyNames[s.faculty2Id!] = s.faculty2Name!;
      }

      if (s.faculty3Id != null) {
        facultyHours[s.faculty3Id!] = (facultyHours[s.faculty3Id!] ?? 0) + hours;
        if (s.faculty3Name != null) facultyNames[s.faculty3Id!] = s.faculty3Name!;
      }
    }

    for (final facultyId in facultyHours.keys) {
      final hours = facultyHours[facultyId]!;
      if (hours > 40) {
        final name = facultyNames[facultyId] ?? "Unknown Faculty";
        _showErrorDialog("Faculty $name requires $hours periods but only 40 periods are available. Please reduce the hours of subjects they teach.");
        return;
      }
    }

    // Check if any subject has lab type and its hours is not 2, 3, or 4
    for (final s in subjects) {
      if (s.subjectType.toLowerCase() == 'lab') {
        final hours = timetableState.workspaceHours[s.id!] ?? 0;
        if (hours > 0 && hours != 2 && hours != 3 && hours != 4) {
          _showErrorDialog("Lab course ${s.courseCode} (${s.courseTitle}) has $hours hours configured. Labs must be configured for exactly 2, 3, or 4 hours for continuous block scheduling.");
          return;
        }
      }
    }

    // 3. Prompt for Timetable Name
    _nameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Timetable Name"),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "Timetable Name",
              hintText: "e.g., ODD SEM 2026, EVEN SEM 2027",
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return "A name is required to save the timetable.";
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.pop(context, _nameController.text.trim());
              }
            },
            child: const Text("Generate"),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      if (!mounted) return;
      
      // Show progress loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Generating conflict-free timetable..."),
            ],
          ),
        ),
      );

      final success = await ref.read(timetableProvider.notifier).generateTimetable(name);

      if (!mounted) return;
      Navigator.pop(context); // Dismiss progress loader

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Timetable '$name' generated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final err = ref.read(timetableProvider).generationError ?? "Unknown error occurred.";
        _showErrorDialog(err);
      }
    }
  }

  void _showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text("Validation Warning"),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Dismiss"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timetableState = ref.watch(timetableProvider);
    final subjectsState = ref.watch(subjectsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: subjectsState.when(
        data: (subjects) {
          if (subjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    "No subjects registered",
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 8),
                  const Text("Please add subjects in the 'Subjects' tab before generating a timetable."),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Set weekly hours for subjects. Labs (continuous blocks) must be 2, 3, or 4 hours.",
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(4, (yearIdx) {
                        final year = yearIdx + 1;
                        final yearSubjects = subjects.where((s) => s.year == year).toList();
                        
                        if (yearSubjects.isEmpty) return const SizedBox.shrink();

                        // Count total configured hours for this year
                        final yearTotalHours = yearSubjects.fold<int>(
                          0,
                          (sum, s) => sum + (timetableState.workspaceHours[s.id!] ?? 0),
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 24),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Year $year",
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    Chip(
                                      label: Text("Total Hours: $yearTotalHours / 40"),
                                      backgroundColor: yearTotalHours > 40 
                                          ? Colors.red.shade100 
                                          : theme.colorScheme.secondaryContainer,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: yearSubjects.length,
                                  separatorBuilder: (c, i) => const Divider(),
                                  itemBuilder: (context, sIdx) {
                                    final subject = yearSubjects[sIdx];
                                    final hours = timetableState.workspaceHours[subject.id!] ?? 0;
                                    
                                    return ListTile(
                                      title: Row(
                                        children: [
                                          Text(
                                            subject.courseCode,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(subject.courseTitle)),
                                          Text(
                                            subject.subjectType,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: subject.subjectType == 'Lab' 
                                                  ? Colors.amber.shade900 
                                                  : theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text("Faculty: ${subject.facultyNames.join(', ')}"),
                                      trailing: SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          initialValue: hours == 0 ? "" : hours.toString(),
                                          decoration: const InputDecoration(
                                            labelText: "Hours/Wk",
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          onChanged: (val) {
                                            final parsed = int.tryParse(val) ?? 0;
                                            ref.read(timetableProvider.notifier).updateWorkspaceHour(subject.id!, parsed);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              // Generate button at bottom
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _triggerGeneration,
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text(
                        "Generate Timetable",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
