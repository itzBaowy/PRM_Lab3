import 'package:fap_attendance/models/workspace.dart';
import 'package:fap_attendance/services/attendance_engine.dart';
import 'package:fap_attendance/services/cloud_workspace_service.dart';
import 'package:fap_attendance/services/store_contract.dart';
import 'package:fap_attendance/services/telemetry_service.dart';

final testDay = DateTime(2026, 11, 11);
Workspace fixture({bool longNames = false}) {
  final engine = AttendanceEngine(now: () => testDay);
  return Workspace(
    ownerUid: 'test-owner',
    email: 'lecturer@example.test',
    classes: [
      ClassRoom(
        id: 'class1',
        code: 'SE1901',
        subject: 'PRM393',
        semester: 'Fall 2026',
        students: [
          Student(
            id: 'SE000001',
            name: longNames
                ? 'Nguyễn Thị Minh Anh với họ và tên rất dài để kiểm tra khả năng xuống dòng'
                : 'Nguyễn Minh Anh',
            email: 'student1@example.test',
          ),
          Student(
            id: 'SE000002',
            name: 'Trần Gia Bảo',
            email: 'student2@example.test',
          ),
        ],
        meetings: engine.schedule(
          classId: 'class1',
          start: testDay,
          weeks: 2,
          rules: [ScheduleRule(testDay.weekday, 1)],
        ),
      ),
    ],
  );
}

class MemoryStore implements WorkspaceStore {
  Workspace? value;
  bool fail = false;
  @override
  Future<Workspace?> load(String uid) async => value?.copy();
  @override
  Future<void> save(Workspace workspace) async {
    if (fail) throw const AppFailure('Lỗi ghi thiết bị');
    value = workspace.copy();
  }

  @override
  Future<void> clear(String uid) async {
    value = null;
  }
}

class MemoryCloud implements CloudWorkspaceService {
  int revision = 0;
  Workspace? value;
  @override
  Future<Workspace?> fetch(String uid) async => value?.copy();
  @override
  Future<int> push(Workspace workspace) async {
    if (workspace.cloudRevision != revision) throw const AppFailure('conflict');
    value = workspace.copy();
    return ++revision;
  }
}

class MemoryTelemetry implements TelemetryService {
  final List<String> events = [];
  @override
  Future<void> event(
    String name, [
    Map<String, Object> parameters = const {},
  ]) async {
    events.add(name);
  }

  @override
  Future<void> identify(String? uid) async {}
  @override
  Future<void> error(Object error, StackTrace stack, String operation) async {}
  @override
  void testCrash() {}
}
