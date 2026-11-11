import 'dart:async';

import '../models/workspace.dart';
import '../services/attendance_engine.dart';
import '../services/attendance_link_service.dart';
import '../services/cloud_workspace_service.dart';
import '../services/store_contract.dart';
import '../services/telemetry_service.dart';
import 'base_vm.dart';

class WorkspaceVm extends BaseVm {
  WorkspaceVm({
    required this.uid,
    required this.store,
    required this.cloud,
    required this.engine,
    required this.links,
    required TelemetryService telemetry,
  }) : super(telemetry);
  final String uid;
  final WorkspaceStore store;
  final CloudWorkspaceService cloud;
  final AttendanceEngine engine;
  final AttendanceLinkService? links;
  Workspace? workspace;
  DateTime week = dateOnly(DateTime.now())
      .subtract(Duration(days: DateTime.now().weekday - 1));
  bool calendarMode = false;
  String rosterQuery = '';
  bool manualMode = true;
  Timer? _poll;

  Future<bool> load() => perform('load_workspace', () async {
    workspace = await store.load(uid);
    if (workspace == null) {
      try {
        workspace = await cloud.fetch(uid).timeout(const Duration(seconds: 10));
      } catch (_) {
        message = 'Chưa tải được dữ liệu cloud. Bạn có thể nhập markbook trên thiết bị.';
      }
    }
    workspace ??= Workspace(ownerUid: uid);
    if (engine.rollover(workspace!)) {
      workspace!.revision++;
      workspace!.syncState = SyncState.pendingSync;
    }
    await store.save(workspace!);
    state = workspace!.visibleClasses.isEmpty
        ? LoadState.empty
        : LoadState.data;
    _poll ??= Timer.periodic(const Duration(seconds: 8), (_) {
      if (!busy) unawaited(receiveLinks());
    });
  }, loading: true);

  Future<void> _persist(void Function(Workspace) mutation) async {
    final next = workspace!.copy();
    mutation(next);
    next.revision++;
    next.syncState = SyncState.pendingSync;
    await store.save(next);
    workspace = next;
    state = next.visibleClasses.isEmpty ? LoadState.empty : LoadState.data;
    message = 'Đã lưu trên máy. Chờ đồng bộ.';
    changed();
  }

  Future<bool> setEmail(String email) => perform('workspace_email', () async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw const AppFailure('Vui lòng nhập email hợp lệ.');
    }
    await _persist((w) => w.email = email.trim());
  });
  Future<bool> importClasses(List<ClassRoom> classes, String format) => perform(
    'import_markbook',
    () async {
      await _persist((w) => engine.merge(w, classes));
      await telemetry.event('import_markbook', {
        'format': format,
        'class_count': classes.length,
        'student_count': classes.fold<int>(0, (n, c) => n + c.students.length),
      });
    },
  );
  Future<bool> configure(
    String classId,
    DateTime start,
    int weeks,
    List<ScheduleRule> rules,
    Set<String> holidays,
    List<DateTime> makeups,
    int makeupSlot,
  ) => perform('configure_schedule', () async {
    final meetings = engine.schedule(
      classId: classId,
      start: start,
      weeks: weeks,
      rules: rules,
      holidays: holidays,
      makeups: makeups,
      makeupSlot: makeupSlot,
    );
    await _persist((w) => engine.configure(w.classroom(classId), meetings));
    await telemetry.event('configure_schedule', {
      'meeting_count': meetings.length,
    });
  });
  Future<bool> start(String classId, String meetingId) =>
      perform('start_meeting', () async {
        await _persist((w) => engine.start(w, classId, meetingId));
      });
  Future<bool> mark(
    String classId,
    String meetingId,
    String studentId,
    Mark value, {
    String? reason,
  }) => perform('attendance_mark', () async {
    final before = workspace!
        .meeting(classId, meetingId)
        .records[studentId]
        ?.mark;
    await _persist(
      (w) => engine.mark(
        w.classroom(classId),
        w.meeting(classId, meetingId),
        studentId,
        value,
        reason: reason,
      ),
    );
    await telemetry.event(
      before == null ? 'attendance_mark' : 'attendance_edit',
      before == null
          ? {'status': value.name, 'mode': 'manual'}
          : {'before': before.name, 'after': value.name},
    );
  });
  Future<void> _drain(
    String classId,
    String meetingId, {
    required bool stop,
  }) async {
    final current = workspace!.meeting(classId, meetingId);
    if (current.linkId == null || links == null) return;
    if (stop) await links!.stop(current.linkId!);
    final ids = await links!.submissions(current.linkId!);
    await _persist((w) {
      final c = w.classroom(classId), m = w.meeting(classId, meetingId);
      // Accept submissions that committed before the server-side stop.
      m.linkOpen = true;
      for (final id in ids) {
        engine.mark(c, m, id, Mark.present, source: 'link');
      }
      if (stop) m.linkOpen = false;
    });
  }

  Future<bool> close(String classId, String meetingId) =>
      perform('attendance_close', () async {
        if (workspace!.meeting(classId, meetingId).linkOpen) {
          await _drain(classId, meetingId, stop: true);
        }
        await _persist(
          (w) =>
              engine.close(w.classroom(classId), w.meeting(classId, meetingId)),
        );
        final m = workspace!.meeting(classId, meetingId);
        await telemetry.event('attendance_close', {
          'present': m.present,
          'absent': m.absent,
        });
      });
  Future<bool> stopLink(String classId, String meetingId) =>
      perform('stop_link', () => _drain(classId, meetingId, stop: true));
  Future<void> attachLink(
    String classId,
    String meetingId,
    LinkSession session,
  ) async => _persist((w) {
    final m = w.meeting(classId, meetingId);
    m.linkId = session.id;
    m.linkOpen = true;
  });
  Future<bool> receiveLinks() => perform('receive_links', () async {
    for (final c in [...?workspace?.visibleClasses]) {
      for (final m in c.meetings.where((m) => m.linkOpen)) {
        final past = m.date.isBefore(dateOnly(engine.now()));
        await _drain(c.id, m.id, stop: past);
      }
    }
    if (workspace != null &&
        workspace!.visibleClasses.any(
          (c) => c.meetings.any(
            (m) =>
                m.state != MeetingState.closed &&
                m.date.isBefore(dateOnly(engine.now())) &&
                !m.linkOpen,
          ),
        )) {
      await _persist(engine.rollover);
    }
  });
  Future<bool> archive(String classId) => perform(
    'archive_class',
    () => _persist((w) => engine.archive(w.classroom(classId))),
  );
  Future<bool> sync() => perform('sync_workspace', () async {
    final next = workspace!.copy();
    try {
      next.cloudRevision = await cloud
          .push(next)
          .timeout(const Duration(seconds: 20));
    } on AppFailure catch (e) {
      if (e.message == 'conflict') {
        next.syncState = SyncState.conflict;
        await store.save(next);
        workspace = next;
      }
      rethrow;
    }
    next.syncState = SyncState.synced;
    await store.save(next);
    workspace = next;
    message = 'Đã đồng bộ Firestore.';
  });
  void moveWeek(int amount) {
    week = week.add(Duration(days: 7 * amount));
    changed();
  }

  void selectWeek(DateTime day) {
    week = dateOnly(day).subtract(Duration(days: day.weekday - 1));
    changed();
  }

  void setCalendar(bool value) {
    calendarMode = value;
    changed();
  }

  void setMode(bool manual) {
    manualMode = manual;
    changed();
  }

  void search(String query) {
    rosterQuery = query;
    changed();
  }

  List<Student> roster(ClassRoom c) => engine.search(c, rosterQuery);
  List<({ClassRoom classroom, Meeting meeting})> meetingsOn(
    DateTime day,
    int slot,
  ) => [
    for (final c in workspace?.visibleClasses ?? <ClassRoom>[])
      for (final m in c.meetings)
        if (dayKey(m.date) == dayKey(day) && m.timeSlot == slot)
          (classroom: c, meeting: m),
  ];
  double absenceRate(ClassRoom c, String studentId) =>
      engine.absenceRate(c, studentId);
  Future<void> track(String event) =>
      telemetry.event(event, {'screen_name': event});
  Future<void> clear() async {
    _poll?.cancel();
    await store.clear(uid);
    workspace = null;
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
