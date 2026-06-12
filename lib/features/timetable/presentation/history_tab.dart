import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'timetable_provider.dart';
import '../domain/timetable_models.dart';
import '../../../presentation/widgets/main_navigation_rail.dart'; // To access the navigation index provider

class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  Future<void> _openFile(BuildContext context, String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await OpenFilex.open(path);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open file: $e"), backgroundColor: Colors.red),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("File not found! It may have been deleted on disk."), backgroundColor: Colors.red),
      );
    }
  }

  void _deleteRecord(BuildContext context, WidgetRef ref, HistoryRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete History Record?"),
        content: Text(
          "Are you sure you want to delete '${record.name}'? "
          "This will also delete the associated PDF and Excel files on disk. "
          "This action cannot be undone.",
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
      await ref.read(timetableProvider.notifier).deleteHistoryRecord(record.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Record '${record.name}' deleted successfully."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(timetableProvider).historyRecords;
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Review and manage previously generated timetables",
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: historyState.when(
                data: (records) {
                  if (records.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(
                            "No history records found",
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                          ),
                          const SizedBox(height: 8),
                          const Text("Timetables you generate will be saved here automatically."),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 36,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Generated: ${record.dateGenerated} at ${record.timeGenerated}",
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                              // Duplication, file launchers, view and delete actions
                              Wrap(
                                spacing: 8,
                                children: [
                                  // View
                                  IconButton.filledTonal(
                                    onPressed: () async {
                                      await ref.read(timetableProvider.notifier).selectHistoryRecord(record);
                                      // Switch tab to View (index 3)
                                      ref.read(navigationProvider.notifier).state = 3;
                                    },
                                    icon: const Icon(Icons.visibility_rounded),
                                    tooltip: "View Timetables",
                                  ),
                                  // Duplicate
                                  IconButton.filledTonal(
                                    onPressed: () async {
                                      await ref.read(timetableProvider.notifier).duplicateTimetable(record);
                                      // Switch tab to Create (index 2)
                                      ref.read(navigationProvider.notifier).state = 2;
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Loaded hours configuration from '${record.name}'. Feel free to edit and generate a new version."),
                                          backgroundColor: theme.colorScheme.primary,
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded),
                                    tooltip: "Duplicate Configuration",
                                  ),
                                  // Open PDF
                                  IconButton(
                                    onPressed: () => _openFile(context, record.pdfPath),
                                    icon: const Icon(Icons.picture_as_pdf_rounded),
                                    color: Colors.red.shade700,
                                    tooltip: "Open PDF File",
                                  ),
                                  // Open Excel
                                  IconButton(
                                    onPressed: () => _openFile(context, record.excelPath),
                                    icon: const Icon(Icons.table_view_rounded),
                                    color: Colors.green.shade700,
                                    tooltip: "Open Excel File",
                                  ),
                                  // Delete
                                  IconButton(
                                    onPressed: () => _deleteRecord(context, ref, record),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    color: theme.colorScheme.error,
                                    tooltip: "Delete Record",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
