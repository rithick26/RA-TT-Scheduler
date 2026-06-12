import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/db/db_helper.dart';
import '../../features/teachers/presentation/teachers_provider.dart';
import '../../features/subjects/presentation/subjects_provider.dart';
import '../../features/timetable/presentation/timetable_provider.dart';
import '../../features/teachers/presentation/teachers_tab.dart';
import '../../features/subjects/presentation/subjects_tab.dart';
import '../../features/timetable/presentation/create_timetable_tab.dart';
import '../../features/timetable/presentation/view_timetable_tab.dart';
import '../../features/timetable/presentation/history_tab.dart';
import '../about_tab.dart';

// Global provider to handle active tab index programmatically
final navigationProvider = StateProvider<int>((ref) => 0);

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  final List<Widget> _tabs = [
    const TeachersTab(),
    const SubjectsTab(),
    const CreateTimetableTab(),
    const ViewTimetableTab(),
    const HistoryTab(),
    const AboutTab(),
  ];

  final List<String> _tabTitles = [
    "Teachers Directory",
    "Subjects Management",
    "Generate Timetable",
    "View Generated Timetables",
    "Timetable History",
    "About Developer",
  ];

  Future<void> _backupDb() async {
    try {
      final dbHelper = DbHelper();

      final String? result = await FilePicker.platform.saveFile(
        dialogTitle: 'Select Backup Location',
        fileName: 'timetable_backup.db',
        type: FileType.any,
      );

      if (result != null) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        await dbHelper.backupDatabase(result);

        if (!mounted) return;
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database backed up successfully to $result'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreDb() async {
    try {
      final dbHelper = DbHelper();

      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Database Backup File',
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;

        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Restore Database?"),
            content: const Text(
              "WARNING: This will replace your current database and all changes will be overwritten. "
              "Are you sure you want to continue?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Restore"),
              ),
            ],
          ),
        );

        if (confirm == true) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );

          await dbHelper.restoreDatabase(path);

          // Refresh providers
          ref.read(teachersProvider.notifier).loadTeachers();
          ref.read(subjectsProvider.notifier).loadSubjects();
          ref.read(timetableProvider.notifier).loadHistory();

          if (!mounted) return;
          Navigator.pop(context); // Close loading

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Reset navigation to Teachers tab
          ref.read(navigationProvider.notifier).state = 0;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = ref.watch(navigationProvider);

    return Scaffold(
      body: Row(
        children: [
          // Navigation rail
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    elevation: 3,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: theme.colorScheme.surfaceVariant
                        .withOpacity(0.3),
                    onDestinationSelected: (int index) {
                      ref.read(navigationProvider.notifier).state = index;
                    },
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "RA TT Scheduler",
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.people_outline_rounded),
                        selectedIcon: Icon(Icons.people_rounded),
                        label: Text('Teachers'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book_rounded),
                        label: Text('Subjects'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.calendar_today_outlined),
                        selectedIcon: Icon(Icons.calendar_today_rounded),
                        label: Text('Create'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.grid_on_outlined),
                        selectedIcon: Icon(Icons.grid_on_rounded),
                        label: Text('View'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_outlined),
                        selectedIcon: Icon(Icons.history_rounded),
                        label: Text('History'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.info_outline_rounded),
                        selectedIcon: Icon(Icons.info_rounded),
                        label: Text('About'),
                      ),
                    ],
                  ),
                ),
                // System Tools (Backup / Restore) at bottom of Navigation Rail
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    children: [
                      Tooltip(
                        message: "Backup database file",
                        child: IconButton(
                          icon: const Icon(Icons.backup_rounded),
                          onPressed: _backupDb,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Tooltip(
                        message: "Restore database from backup",
                        child: IconButton(
                          icon: const Icon(
                            Icons.settings_backup_restore_rounded,
                          ),
                          onPressed: _restoreDb,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main content area
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  _tabTitles[selectedIndex],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                elevation: 0,
                backgroundColor: theme.colorScheme.surface,
              ),
              body: Container(
                color: theme.colorScheme.background,
                child: _tabs[selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
