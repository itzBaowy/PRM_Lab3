import 'package:flutter_test/flutter_test.dart';
import 'package:fap_attendance/models/workspace.dart';
import 'package:fap_attendance/services/attendance_engine.dart';
import 'support.dart';

void main() {
  late Workspace w;
  late AttendanceEngine engine;
  late ClassRoom c;
  late Meeting m;
  setUp(() { w = fixture(); engine = AttendanceEngine(now: () => testDay); c = w.classes.single; m = c.meetings.first; });
  test('BR01 unknown remains unknown until finalize', () { expect(m.records, isEmpty); engine.start(w, c.id, m.id); expect(m.records, isEmpty); });
  test('BR02 start restricted to today', () { expect(() => engine.start(w, c.id, c.meetings.last.id), throwsA(isA<AppFailure>())); });
  test('BR03 only one active meeting', () { engine.start(w, c.id, m.id); final other = Meeting(id: 'other', date: testDay, timeSlot: 2, number: 3); c.meetings.add(other); expect(() => engine.start(w, c.id, other.id), throwsA(isA<AppFailure>())); });
  test('BR04 link never overwrites manual and duplicate is idempotent', () {
    engine.start(w, c.id, m.id); m.linkOpen = true;
    engine.mark(c, m, 'SE000001', Mark.absent);
    engine.mark(c, m, 'SE000001', Mark.present, source: 'link');
    engine.mark(c, m, 'SE000002', Mark.present, source: 'link');
    engine.mark(c, m, 'SE000002', Mark.present, source: 'link');
    expect(m.absent, 1); expect(m.present, 1); expect(m.records.length, 2);
  });
  test('BR05 nonmember rejected', () { engine.start(w, c.id, m.id); expect(() => engine.mark(c, m, 'outsider', Mark.present), throwsA(isA<AppFailure>())); });
  test('BR06 reason is mandatory and new audit captures before after', () {
    engine.start(w, c.id, m.id); engine.mark(c, m, 'SE000001', Mark.present);
    expect(() => engine.mark(c, m, 'SE000001', Mark.absent, reason: '  '), throwsA(isA<AppFailure>()));
    engine.mark(c, m, 'SE000001', Mark.absent, reason: 'Xác nhận lại với giảng viên');
    final audit = m.records['SE000001']!.audit.single;
    expect(audit.before, Mark.present); expect(audit.after, Mark.absent); expect(audit.reason, 'Xác nhận lại với giảng viên');
  });
  test('BR07 finalize retains P and fills only unknown A', () { engine.start(w, c.id, m.id); engine.mark(c, m, 'SE000001', Mark.present); m.linkOpen = true; engine.close(c, m); expect(m.present, 1); expect(m.absent, 1); expect(m.state, MeetingState.closed); expect(m.linkOpen, false); });
  test('BR08 closed never reopens', () { engine.start(w, c.id, m.id); engine.close(c, m); expect(() => engine.start(w, c.id, m.id), throwsA(isA<AppFailure>())); });
  test('BR09 future edit forbidden even with reason', () { expect(() => engine.mark(c, m, 'SE000001', Mark.present, reason: 'test'), throwsA(isA<AppFailure>())); });
  test('BR10 schedule cannot change after attendance starts', () { engine.start(w, c.id, m.id); expect(() => engine.configure(c, []), throwsA(isA<AppFailure>())); });
  test('BR11 holiday removed and Sunday makeup retained', () {
    final sunday = testDay.add(Duration(days: 7 - testDay.weekday));
    final meetings = engine.schedule(classId: c.id, start: testDay, weeks: 2, rules: [ScheduleRule(testDay.weekday, 1)], holidays: {dayKey(testDay)}, makeups: [sunday], makeupSlot: 3);
    expect(meetings.length, 2); expect(meetings.first.date.weekday, 7); expect(meetings.first.timeSlot, 3); expect(meetings.map((m) => m.number), [1, 2]);
  });
  test('BR12 invalid weeks and duplicate rule rejected', () {
    expect(() => engine.schedule(classId: c.id, start: testDay, weeks: 53, rules: [const ScheduleRule(1, 1)]), throwsA(isA<AppFailure>()));
    expect(() => engine.schedule(classId: c.id, start: testDay, weeks: 1, rules: [const ScheduleRule(1, 1), const ScheduleRule(1, 1)]), throwsA(isA<AppFailure>()));
  });
  test('BR13 rollover fills unknown, retains existing', () { engine.start(w, c.id, m.id); engine.mark(c, m, 'SE000001', Mark.present); final tomorrow = AttendanceEngine(now: () => testDay.add(const Duration(days: 1))); expect(tomorrow.rollover(w), true); expect(m.present, 1); expect(m.absent, 1); });
  test('BR14 absence denominator includes future', () { engine.start(w, c.id, m.id); engine.mark(c, m, 'SE000001', Mark.absent); expect(engine.absenceRate(c, 'SE000001'), 0.5); c.meetings.clear(); expect(engine.absenceRate(c, 'SE000001'), 0); });
  test('BR15 reimport preserves records and adds A to new students', () {
    engine.start(w, c.id, m.id); engine.mark(c, m, 'SE000001', Mark.present); engine.close(c, m);
    final incoming = fixture().classes.single; incoming.students.clear(); incoming.students.add(Student(id: 'SE000003', name: 'Lê An', email: 'third@example.test'));
    engine.merge(w, [incoming]); expect(c.students.length, 3); expect(m.present, 1); expect(m.absent, 2); expect(c.meetings.length, 2);
  });
  test('BR16 active class cannot be archived', () { engine.start(w, c.id, m.id); expect(() => engine.archive(c), throwsA(isA<AppFailure>())); engine.close(c, m); engine.archive(c); expect(w.visibleClasses, isEmpty); expect(w.classes, hasLength(1)); });
  test('serialization preserves full audit', () { engine.start(w, c.id, m.id); engine.mark(c, m, 'SE000001', Mark.present); engine.mark(c, m, 'SE000001', Mark.absent, reason: 'Correction'); expect(w.copy().toJson(), w.toJson()); });
}
