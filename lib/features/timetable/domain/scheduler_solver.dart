import 'dart:math';
import '../../subjects/domain/subject.dart';
import 'timetable_models.dart';

class SchedulerException implements Exception {
  final String message;
  SchedulerException(this.message);
  @override
  String toString() => message;
}

class SchedulerSolver {
  final List<Subject> subjects;
  final Map<int, int> hoursPerWeek; // subjectId -> hours
  static const theoryPairs = [
    [0, 1],
    [2, 3],
    [4, 5],
    [6, 7],
  ];

  static const afternoonPairs = [
    [4, 5],
    [6, 7],
  ];

  SchedulerSolver({required this.subjects, required this.hoursPerWeek});

  // Run validation checks. Throws SchedulerException if unsolvable.
  void validate() {
    // 1. Single course hours check
    for (final subject in subjects) {
      final hours = hoursPerWeek[subject.id] ?? 0;
      if (hours > 40) {
        throw SchedulerException(
          "Course ${subject.courseCode} (${subject.courseTitle}) requires $hours hours, which exceeds the maximum weekly capacity of 40 slots.",
        );
      }
    }

    // 2. Year hours check
    for (int year = 1; year <= 4; year++) {
      final yearSubjects = subjects.where((s) => s.year == year).toList();
      final totalHours = yearSubjects.fold<int>(
        0,
        (sum, s) => sum + (hoursPerWeek[s.id] ?? 0),
      );
      if (totalHours > 40) {
        throw SchedulerException(
          "Year $year requires $totalHours hours in total, but only 40 weekly slots are available.",
        );
      }
    }

    // 3. Global Faculty Workload check (across all years)
    final facultyHours = <int, int>{}; // facultyId -> totalHours
    final facultyNames = <int, String>{}; // facultyId -> name

    for (final subject in subjects) {
      final hours = hoursPerWeek[subject.id] ?? 0;
      if (hours == 0) continue;

      // Add hours for Faculty 1
      facultyHours[subject.faculty1Id] =
          (facultyHours[subject.faculty1Id] ?? 0) + hours;
      if (subject.faculty1Name != null) {
        facultyNames[subject.faculty1Id] = subject.faculty1Name!;
      }

      // Add hours for Faculty 2
      if (subject.faculty2Id != null) {
        facultyHours[subject.faculty2Id!] =
            (facultyHours[subject.faculty2Id!] ?? 0) + hours;
        if (subject.faculty2Name != null) {
          facultyNames[subject.faculty2Id!] = subject.faculty2Name!;
        }
      }

      // Add hours for Faculty 3
      if (subject.faculty3Id != null) {
        facultyHours[subject.faculty3Id!] =
            (facultyHours[subject.faculty3Id!] ?? 0) + hours;
        if (subject.faculty3Name != null) {
          facultyNames[subject.faculty3Id!] = subject.faculty3Name!;
        }
      }
    }

    for (final facultyId in facultyHours.keys) {
      final hours = facultyHours[facultyId]!;
      if (hours > 40) {
        final name =
            facultyNames[facultyId] ?? "Unknown Faculty (ID: $facultyId)";
        throw SchedulerException(
          "Faculty $name requires $hours periods but only 40 periods are available.",
        );
      }
    }
    for (final subject in subjects) {
      final hours = hoursPerWeek[subject.id] ?? 0;

      final type = subject.subjectType.toLowerCase();

      if (type == 'theory' && hours % 2 != 0) {
        throw SchedulerException(
          '${subject.courseCode} theory subject must have even hours.',
        );
      }

      if ((type == 'project' || type == 'additional') && hours % 2 != 0) {
        throw SchedulerException(
          '${subject.courseCode} must be allocated in pairs.',
        );
      }
    }
  }

  // Solves the CSP problem and returns a list of TimetableSlot objects.
  List<TimetableSlot> solve({int seed = 42}) {
    // Run pre-validations
    validate();

    final rand = Random(seed);
    const int maxRestarts = 20;
    const int maxIterationsPerRun = 50000;

    for (int run = 0; run < maxRestarts; run++) {
      try {
        final result = _trySolve(rand, maxIterationsPerRun);
        if (result != null) {
          return result;
        }
      } catch (e) {
        // If it was a SchedulerException, propagate it; otherwise try next restart
        if (e is SchedulerException) rethrow;
      }
    }

    throw SchedulerException(
      "Unable to find a collision-free timetable under the current constraints. "
      "Please adjust the hours per week or faculty assignments.",
    );
  }

  List<TimetableSlot>? _trySolve(Random rand, int maxIterations) {
    // Grid representation: [year (1..4)][day (0..4)][period (0..8)] -> Subject
    // We adjust year indices 1..4 to 0..3 for array indexing
    final grid = List.generate(
      4,
      (_) => List.generate(5, (_) => List<Subject?>.filled(8, null)),
    );

    // Track remaining hours to schedule for each subject
    final remainingHours = <int, int>{};
    for (final s in subjects) {
      remainingHours[s.id!] = hoursPerWeek[s.id!] ?? 0;
    }

    // List of labs to schedule
    final labs = subjects
        .where(
          (s) =>
              s.subjectType.toLowerCase() == 'lab' &&
              (hoursPerWeek[s.id!] ?? 0) > 0,
        )
        .toList();
    // Sort labs by hours descending to place larger labs first (heuristics)
    labs.sort(
      (a, b) => (hoursPerWeek[b.id!] ?? 0).compareTo(hoursPerWeek[a.id!] ?? 0),
    );

    // List of theories/projects/others to schedule
    final theories = subjects
        .where(
          (s) =>
              s.subjectType.toLowerCase() != 'lab' &&
              (hoursPerWeek[s.id!] ?? 0) > 0,
        )
        .toList();

    // 1. Backtracking to schedule all labs first
    if (!_scheduleLabs(grid, labs, remainingHours, 0, rand)) {
      return null;
    }

    // 2. Backtracking to schedule all theory subjects
    int iterations = 0;
    bool success = _scheduleTheories(
      grid,
      theories,
      remainingHours,
      0,
      0,
      0,
      rand,
      () {
        iterations++;
        return iterations > maxIterations;
      },
    );

    if (!success) return null;

    // Convert grid to TimetableSlot objects
    final slots = <TimetableSlot>[];
    for (int yIdx = 0; yIdx < 4; yIdx++) {
      final year = yIdx + 1;
      for (int d = 0; d < 5; d++) {
        for (int p = 0; p < 8; p++) {
          final sub = grid[yIdx][d][p];
          slots.add(
            TimetableSlot(
              historyId: 0, // Set later
              year: year,
              day: d,
              period: p,
              subjectId: sub?.id,
              subject: sub,
            ),
          );
        }
      }
    }
    return slots;
  }

  // Recursive lab placement
  bool _scheduleLabs(
    List<List<List<Subject?>>> grid,
    List<Subject> labs,
    Map<int, int> remaining,
    int labIdx,
    Random rand,
  ) {
    if (labIdx >= labs.length) return true;

    final lab = labs[labIdx];
    final hours = remaining[lab.id!]!;
    final yearIdx = lab.year - 1;

    // A lab must be scheduled in a single block of H consecutive periods on one day
    // Generate all candidate slots: (day, startPeriod)
    final candidates = <MapEntry<int, int>>[];
    for (int d = 0; d < 5; d++) {
      if (hours == 2) {
        candidates.add(MapEntry(d, 0)); // P1-P2
        candidates.add(MapEntry(d, 2)); // P3-P4
        candidates.add(MapEntry(d, 4)); // P5-P6
        candidates.add(MapEntry(d, 6)); // P7-P8
      } else if (hours == 3) {
        candidates.add(MapEntry(d, 0)); // P1-P2-P3
        candidates.add(MapEntry(d, 2)); // P3-P4-P5
        candidates.add(MapEntry(d, 4)); // P5-P6-P7
      } else if (hours == 4) {
        candidates.add(MapEntry(d, 0)); // P1-P2-P3-P4
        candidates.add(MapEntry(d, 4)); // P5-P6-P7-P8
      }
    }
    candidates.shuffle(rand);

    for (final candidate in candidates) {
      final d = candidate.key;
      final startP = candidate.value;

      bool canPlace = true;
      // Check if all periods in this block are empty for this year, and no teacher clashes in other years
      for (int p = startP; p < startP + hours; p++) {
        if (grid[yearIdx][d][p] != null) {
          canPlace = false;
          break;
        }
        if (_hasTeacherClash(grid, lab, d, p, yearIdx)) {
          canPlace = false;
          break;
        }
      }

      if (canPlace) {
        // Place the lab block
        for (int p = startP; p < startP + hours; p++) {
          grid[yearIdx][d][p] = lab;
        }
        remaining[lab.id!] = 0;

        if (_scheduleLabs(grid, labs, remaining, labIdx + 1, rand)) {
          return true;
        }

        // Backtrack
        for (int p = startP; p < startP + hours; p++) {
          grid[yearIdx][d][p] = null;
        }
        remaining[lab.id!] = hours;
      }
    }

    return false;
  }

  // Recursive theory placement
  bool _scheduleTheories(
    List<List<List<Subject?>>> grid,
    List<Subject> theories,
    Map<int, int> remaining,
    int yearIdx,
    int d,
    int p,
    Random rand,
    bool Function() isTimeout,
  ) {
    if (isTimeout()) return false;

    // Move to next slot
    if (p >= 8) {
      p = 0;
      d++;
    }
    if (d >= 5) {
      d = 0;
      yearIdx++;
    }
    if (yearIdx >= 4) {
      // Check if all hours have been scheduled
      for (final sId in remaining.keys) {
        if (remaining[sId]! > 0) return false;
      }
      return true;
    }

    // If slot is already occupied (e.g. by a lab), skip to next slot
    if (grid[yearIdx][d][p] != null) {
      return _scheduleTheories(
        grid,
        theories,
        remaining,
        yearIdx,
        d,
        p + 2,
        rand,
        isTimeout,
      );
    }

    final year = yearIdx + 1;
    // Get candidate subjects for this year that still have remaining hours
    final candidates = theories
        .where((s) => s.year == year && remaining[s.id!]! > 0)
        .toList();

    // Shuffling candidate subjects adds randomness to avoid local traps
    candidates.shuffle(rand);

    for (final s in candidates) {
      if (_canPlaceTheory(grid, s, d, p, yearIdx, remaining)) {
        final type = s.subjectType.toLowerCase();

        if (type == 'theory' || type == 'project' || type == 'additional') {
          grid[yearIdx][d][p] = s;
          grid[yearIdx][d][p + 1] = s;

          remaining[s.id!] = remaining[s.id!]! - 2;
        } else {
          grid[yearIdx][d][p] = s;

          remaining[s.id!] = remaining[s.id!]! - 1;
        }

        if (_scheduleTheories(
          grid,
          theories,
          remaining,
          yearIdx,
          d,
          p + 2,
          rand,
          isTimeout,
        )) {
          return true;
        }

        // Backtrack
        if (type == 'theory' || type == 'project' || type == 'additional') {
          grid[yearIdx][d][p] = null;
          grid[yearIdx][d][p + 1] = null;

          remaining[s.id!] = remaining[s.id!]! + 2;
        } else {
          grid[yearIdx][d][p] = null;

          remaining[s.id!] = remaining[s.id!]! + 1;
        }
      }
    }

    // Try leaving this slot empty (null) as a fallback
    final totalRemainingForYear = theories
        .where((s) => s.year == year)
        .fold<int>(0, (sum, s) => sum + remaining[s.id!]!);
    final emptySlotsCount = _countEmptySlots(grid, yearIdx);

    if (emptySlotsCount > totalRemainingForYear) {
      grid[yearIdx][d][p] = null;
      if (_scheduleTheories(
        grid,
        theories,
        remaining,
        yearIdx,
        d,
        p + 2,
        rand,
        isTimeout,
      )) {
        return true;
      }
    }

    return false;
  }

  // Count empty slots for a year
  int _countEmptySlots(List<List<List<Subject?>>> grid, int yearIdx) {
    int count = 0;
    for (int d = 0; d < 5; d++) {
      for (int p = 0; p < 8; p++) {
        if (grid[yearIdx][d][p] == null) count++;
      }
    }
    return count;
  }

  // Check if a theory subject can be placed in (d, p) for yearIdx
  bool _canPlaceTheory(
    List<List<List<Subject?>>> grid,
    Subject subject,
    int d,
    int p,
    int yearIdx,
    Map<int, int> remaining,
  ) {
    final type = subject.subjectType.toLowerCase();
    if (type == 'project' || type == 'additional') {
      if (!(p == 4 || p == 6)) {
        return false;
      }

      if (p + 1 >= 8) return false;

      if (grid[yearIdx][d][p + 1] != null) {
        return false;
      }

      if (_hasTeacherClash(grid, subject, d, p + 1, yearIdx)) {
        return false;
      }
    }

    if (type == 'theory') {
      // Theory can start only at P1,P3,P5,P7
      if (!(p == 0 || p == 2 || p == 4 || p == 6)) {
        return false;
      }

      // Need both periods free
      if (p + 1 >= 8) return false;

      if (grid[yearIdx][d][p + 1] != null) {
        return false;
      }

      // Teacher clash for second period
      if (_hasTeacherClash(grid, subject, d, p + 1, yearIdx)) {
        return false;
      }
    }

    // 1. Teacher clash check
    if (_hasTeacherClash(grid, subject, d, p, yearIdx)) return false;

    // 2. Max hours per day for this subject
    // Avoid teaching the same theory subject too many times in a single day

    int dailyCount = 0;
    for (int i = 0; i < 8; i++) {
      if (grid[yearIdx][d][i]?.id == subject.id) {
        dailyCount++;
      }
    }

    // Maximum 4 periods (2 pairs) of same subject per day
    if (dailyCount >= 4) return false;

    return true;
  }

  // Checks if any teacher of the subject is busy in (day, period) in any other year
  bool _hasTeacherClash(
    List<List<List<Subject?>>> grid,
    Subject subject,
    int day,
    int period,
    int ignoreYearIdx,
  ) {
    final teachers = <int>[];
    teachers.add(subject.faculty1Id);
    if (subject.faculty2Id != null) teachers.add(subject.faculty2Id!);
    if (subject.faculty3Id != null) teachers.add(subject.faculty3Id!);

    for (int y = 0; y < 4; y++) {
      if (y == ignoreYearIdx) continue;
      final otherSubject = grid[y][day][period];
      if (otherSubject != null) {
        // Check if other subject has any of our teachers
        if (teachers.contains(otherSubject.faculty1Id) ||
            (otherSubject.faculty2Id != null &&
                teachers.contains(otherSubject.faculty2Id!)) ||
            (otherSubject.faculty3Id != null &&
                teachers.contains(otherSubject.faculty3Id!))) {
          return true;
        }
      }
    }
    return false;
  }
}
