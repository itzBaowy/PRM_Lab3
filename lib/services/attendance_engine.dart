import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/workspace.dart';

class AttendanceEngine {
  AttendanceEngine({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  String idFor(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 24);

  List<Meeting> schedule({
    required String classId,
    required DateTime start,
    required int weeks,
    required List<ScheduleRule> rules,
    Set<String> holidays = const {},
    List<DateTime> makeups = const [],
    int makeupSlot = 1,
  }) {
    if (weeks < 1 ||
        weeks > 52 ||
        rules.isEmpty ||
        rules.length > 2 ||
        rules.any(
          (r) =>
              r.weekday < 1 ||
              r.weekday > 7 ||
              r.timeSlot < 1 ||
              r.timeSlot > 4,
        ) ||
        makeupSlot < 1 ||
        makeupSlot > 4) {
      throw const AppFailure(
        'Số tuần phải từ 1–52, có 1 hoặc 2 slot/tuần, khung giờ từ 1–4.',
      );
    }
    if (rules.map((r) => '${r.weekday}-${r.timeSlot}').toSet().length !=
        rules.length) {
      throw const AppFailure(
        'Hai slot trong tuần không được trùng ngày và khung giờ.',
      );
    }
    final dates = <String, Meeting>{};
    void add(DateTime date, int slot) {
      final key = '${dayKey(date)}-$slot';
      dates[key] = Meeting(
        id: idFor('$classId-$key'),
        date: dateOnly(date),
        timeSlot: slot,
        number: 0,
      );
    }

    for (var i = 0; i < weeks * 7; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      if (holidays.contains(dayKey(date))) continue;
      for (final rule in rules.where((r) => r.weekday == date.weekday)) {
        add(date, rule.timeSlot);
      }
    }
    for (final date in makeups) {
      add(date, makeupSlot);
    }
    final result = dates.values.toList()
      ..sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        return cmp == 0 ? a.timeSlot.compareTo(b.timeSlot) : cmp;
      });
    for (var i = 0; i < result.length; i++) {
      result[i].number = i + 1;
    }
    return result;
  }

  void configure(ClassRoom c, List<Meeting> meetings) {
    if (c.meetings.any(
      (m) =>
          m.state != MeetingState.upcoming || m.date.isBefore(dateOnly(now())),
    )) {
      throw const AppFailure(
        'Không thể đổi lịch vì lớp đã có slot bắt đầu hoặc đã chốt.',
      );
    }
    c.meetings = meetings;
  }

  void start(Workspace w, String classId, String meetingId) {
    final m = w.meeting(classId, meetingId);
    if (m.state == MeetingState.closed) {
      throw const AppFailure('Buổi học đã chốt.');
    }
    if (dayKey(m.date) != dayKey(now())) {
      throw const AppFailure('Chỉ bắt đầu điểm danh cho ngày hiện tại.');
    }
    if (w.classes.any(
      (c) => c.meetings.any(
        (other) => other.state == MeetingState.active && other.id != m.id,
      ),
    )) {
      throw const AppFailure(
        'Hãy chốt buổi đang điểm danh trước khi bắt đầu buổi khác.',
      );
    }
    m.state = MeetingState.active;
  }

  void mark(
    ClassRoom c,
    Meeting m,
    String studentId,
    Mark value, {
    String? reason,
    String source = 'manual',
  }) {
    if (!c.students.any((s) => s.id == studentId)) {
      throw const AppFailure('Sinh viên không thuộc danh sách lớp.');
    }
    if (m.state == MeetingState.upcoming) {
      throw const AppFailure('Hãy bắt đầu buổi học trước khi điểm danh.');
    }
    final previous = m.records[studentId];
    if (source == 'link') {
      if (m.state != MeetingState.active || !m.linkOpen || previous != null) {
        return;
      }
      m.records[studentId] = AttendanceRecord(
        mark: Mark.present,
        source: 'link',
      );
      return;
    }
    if (previous?.mark == value) return;
    if ((previous != null || m.state == MeetingState.closed) &&
        (reason == null || reason.trim().isEmpty)) {
      throw const AppFailure('Vui lòng nhập lý do chỉnh sửa.');
    }
    final audit = [...?previous?.audit];
    if (previous != null || m.state == MeetingState.closed) {
      audit.add(
        AuditEntry(
          before: previous?.mark,
          after: value,
          reason: reason!.trim(),
          at: now().toUtc(),
        ),
      );
    }
    m.records[studentId] = AttendanceRecord(
      mark: value,
      source: 'manual',
      audit: audit,
    );
  }

  void close(ClassRoom c, Meeting m) {
    if (m.state != MeetingState.active) {
      throw const AppFailure('Buổi học chưa bắt đầu hoặc đã chốt.');
    }
    _complete(c, m);
  }

  void _complete(ClassRoom c, Meeting m) {
    for (final s in c.students) {
      m.records.putIfAbsent(
        s.id,
        () => AttendanceRecord(mark: Mark.absent, source: 'finalize'),
      );
    }
    m.state = MeetingState.closed;
    m.linkOpen = false;
  }

  bool rollover(Workspace w) {
    var changed = false;
    for (final c in w.visibleClasses) {
      for (final m in c.meetings) {
        // Open cloud links must be drained by the orchestrator before rollover.
        if (m.state != MeetingState.closed &&
            !m.linkOpen &&
            m.date.isBefore(dateOnly(now()))) {
          _complete(c, m);
          changed = true;
        }
      }
    }
    return changed;
  }

  void merge(Workspace w, List<ClassRoom> incoming) {
    for (final fresh in incoming) {
      final existing = w.classes.where((c) => c.id == fresh.id).firstOrNull;
      if (existing == null) {
        w.classes.add(fresh);
        continue;
      }
      existing.archived = false;
      for (final student in fresh.students) {
        final sameEmail = existing.students.where(
          (s) => s.email == student.email && s.id != student.id,
        );
        if (sameEmail.isNotEmpty) {
          throw const AppFailure('Email đã gắn với MSSV khác trong lớp.');
        }
        final index = existing.students.indexWhere((s) => s.id == student.id);
        if (index >= 0) {
          existing.students[index] = student;
        } else {
          existing.students.add(student);
          for (final m in existing.meetings.where(
            (m) => m.state == MeetingState.closed,
          )) {
            m.records[student.id] = AttendanceRecord(
              mark: Mark.absent,
              source: 'import',
            );
          }
        }
      }
    }
  }

  void archive(ClassRoom c) {
    if (c.meetings.any((m) => m.state == MeetingState.active)) {
      throw const AppFailure('Không thể xóa lớp đang điểm danh.');
    }
    c.archived = true;
  }

  double absenceRate(ClassRoom c, String studentId) => c.meetings.isEmpty
      ? 0
      : c.meetings
                .where((m) => m.records[studentId]?.mark == Mark.absent)
                .length /
            c.meetings.length;
  List<Student> search(ClassRoom c, String query) => c.students
      .where(
        (s) => '${s.name} ${s.id}'.toLowerCase().contains(
          query.trim().toLowerCase(),
        ),
      )
      .toList();
}
