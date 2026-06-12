import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'teachers_provider.dart';
import '../domain/teacher.dart';

class TeachersTab extends ConsumerStatefulWidget {
  const TeachersTab({super.key});

  @override
  ConsumerState<TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends ConsumerState<TeachersTab> {
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  void _showAddEditDialog([Teacher? teacher]) {
    final isEditing = teacher != null;
    if (isEditing) {
      _nameController.text = teacher.name;
      _designationController.text = teacher.designation;
    } else {
      _nameController.clear();
      _designationController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit Teacher" : "Add Teacher"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Teacher Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the teacher's name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _designationController,
                decoration: const InputDecoration(
                  labelText: "Designation",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter their designation";
                  }
                  return null;
                },
              ),
            ],
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
                final notifier = ref.read(teachersProvider.notifier);
                try {
                  if (isEditing) {
                    await notifier.updateTeacher(teacher.copyWith(
                      name: _nameController.text,
                      designation: _designationController.text,
                    ));
                  } else {
                    await notifier.addTeacher(
                      _nameController.text,
                      _designationController.text,
                    );
                  }
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteTeacher(Teacher teacher) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Teacher?"),
        content: Text("Are you sure you want to delete ${teacher.name}?"),
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
        await ref.read(teachersProvider.notifier).deleteTeacher(teacher.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${teacher.name} deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Cannot Delete Teacher"),
              content: Text(e.toString().replaceFirst("Exception: ", "")),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _importExcel() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      dialogTitle: 'Select Teachers Excel File',
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
        final count = await ref.read(teachersProvider.notifier).importFromExcel(path);
        
        if (!mounted) return;
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0 
                ? 'Successfully imported $count new teachers!' 
                : 'No new teachers imported (they may already exist).'),
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
    final teachersState = ref.watch(teachersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Add Teacher"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Faculty list for scheduling classes",
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
              child: teachersState.when(
                data: (teachers) {
                  if (teachers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(
                            "No teachers found",
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                          ),
                          const SizedBox(height: 8),
                          const Text("Add teachers or import them using an Excel sheet to begin."),
                        ],
                      ),
                    );
                  }

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 1,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          ),
                          columns: const [
                            DataColumn(label: Text('Teacher Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: teachers.map((teacher) {
                            return DataRow(
                              cells: [
                                DataCell(Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(Text(teacher.designation)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: "Edit",
                                        onPressed: () => _showAddEditDialog(teacher),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                        tooltip: "Delete",
                                        onPressed: () => _deleteTeacher(teacher),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
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
