import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_scheduler/features/subjects/domain/subject.dart';
import 'package:timetable_scheduler/features/timetable/domain/scheduler_solver.dart';

void main() {
  group('Timetable Scheduler Solver Tests', () {
    test('Successful timetable generation for valid subjects and hours', () {
      final subjects = [
        Subject(id: 1, courseCode: '20RA206', courseTitle: 'Industrial Robotics', year: 1, semester: 1, subjectType: 'Theory', faculty1Id: 101, faculty1Name: 'Dr. Kumar'),
        Subject(id: 2, courseCode: '20RA207', courseTitle: 'Kinematics', year: 1, semester: 1, subjectType: 'Theory', faculty1Id: 102, faculty1Name: 'Dr. Ravi'),
        Subject(id: 3, courseCode: '20RA208', courseTitle: 'Robotics Lab', year: 1, semester: 1, subjectType: 'Lab', faculty1Id: 101, faculty1Name: 'Dr. Kumar'), // Lab
      ];

      final hours = {
        1: 4, // 4 hours Theory
        2: 5, // 5 hours Theory
        3: 3, // 3 hours Lab (should be consecutive)
      };

      final solver = SchedulerSolver(subjects: subjects, hoursPerWeek: hours);
      
      // Should not throw any exception
      expect(() => solver.validate(), returnsNormally);

      final slots = solver.solve();
      expect(slots, isNotEmpty);
      expect(slots.length, equals(160)); // 4 years * 40 slots = 160

      // Filter scheduled slots for Year 1
      final year1Slots = slots.where((s) => s.year == 1 && s.subjectId != null).toList();
      expect(year1Slots.length, equals(12)); // 4 + 5 + 3 = 12 hours scheduled

      // Verify lab slots are consecutive
      final labSlots = year1Slots.where((s) => s.subjectId == 3).toList();
      expect(labSlots.length, equals(3));
      final labDay = labSlots.first.day;
      for (final s in labSlots) {
        expect(s.day, equals(labDay)); // Must be on same day
      }
      final periods = labSlots.map((s) => s.period).toList()..sort();
      expect(periods[1] - periods[0], equals(1)); // Must be adjacent
      expect(periods[2] - periods[1], equals(1));
    });

    test('Throws validation error when faculty workload exceeds 40 hours', () {
      final subjects = [
        Subject(id: 1, courseCode: '20RA206', courseTitle: 'Industrial Robotics', year: 1, semester: 1, subjectType: 'Theory', faculty1Id: 101, faculty1Name: 'Dr. Kumar'),
        Subject(id: 2, courseCode: '20RA207', courseTitle: 'Kinematics', year: 2, semester: 3, subjectType: 'Theory', faculty1Id: 101, faculty1Name: 'Dr. Kumar'),
      ];

      final hours = {
        1: 25,
        2: 20, // Total = 45 hours for Dr. Kumar (exceeds 40)
      };

      final solver = SchedulerSolver(subjects: subjects, hoursPerWeek: hours);

      expect(
        () => solver.validate(),
        throwsA(isA<SchedulerException>().having(
          (e) => e.message,
          'message',
          contains('Faculty Dr. Kumar requires 45 periods but only 40 periods are available.'),
        )),
      );
    });

    test('Throws validation error when year workload exceeds 40 hours', () {
      final subjects = [
        Subject(id: 1, courseCode: '20RA206', courseTitle: 'Robotics', year: 1, semester: 1, subjectType: 'Theory', faculty1Id: 101, faculty1Name: 'Dr. Kumar'),
        Subject(id: 2, courseCode: '20RA207', courseTitle: 'Control Systems', year: 1, semester: 1, subjectType: 'Theory', faculty1Id: 102, faculty1Name: 'Dr. Ravi'),
      ];

      final hours = {
        1: 25,
        2: 20, // Total Year 1 = 45 hours (exceeds 40)
      };

      final solver = SchedulerSolver(subjects: subjects, hoursPerWeek: hours);

      expect(
        () => solver.validate(),
        throwsA(isA<SchedulerException>().having(
          (e) => e.message,
          'message',
          contains('Year 1 requires 45 hours in total, but only 40 weekly slots are available.'),
        )),
      );
    });
  });
}
