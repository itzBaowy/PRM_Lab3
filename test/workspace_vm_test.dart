import 'package:flutter_test/flutter_test.dart';
import 'package:fap_attendance/models/workspace.dart';
import 'package:fap_attendance/services/attendance_engine.dart';
import 'package:fap_attendance/viewmodels/workspace_vm.dart';

import 'support.dart';

void main() {
  late MemoryStore store;
  late MemoryCloud cloud;
  late WorkspaceVm vm;
  setUp(() async {
    store = MemoryStore()..value = fixture();
    cloud = MemoryCloud();
    vm = WorkspaceVm(
      uid: 'test-owner',
      store: store,
      cloud: cloud,
      engine: AttendanceEngine(now: () => testDay),
      links: null,
      telemetry: MemoryTelemetry(),
    );
    await vm.load();
  });
  tearDown(() => vm.dispose());
  test(
    'failed persistence does not report saved or mutate live state',
    () async {
      final c = vm.workspace!.classes.single;
      store.fail = true;
      expect(await vm.start(c.id, c.meetings.first.id), false);
      expect(
        vm.workspace!.classes.single.meetings.first.state,
        MeetingState.upcoming,
      );
      expect(vm.error, isNotNull);
      expect(vm.message, isNull);
    },
  );
  test('manual workflow works entirely without cloud', () async {
    final c = vm.workspace!.classes.single, m = c.meetings.first;
    expect(await vm.start(c.id, m.id), true);
    expect(await vm.mark(c.id, m.id, 'SE000001', Mark.present), true);
    expect(await vm.close(c.id, m.id), true);
    expect(store.value!.meeting(c.id, m.id).present, 1);
    expect(store.value!.meeting(c.id, m.id).absent, 1);
    expect(vm.workspace!.syncState, SyncState.pendingSync);
  });
  test('cloud conflict preserves local workspace', () async {
    cloud.revision = 2;
    final before = vm.workspace!.classes.single.students.length;
    expect(await vm.sync(), false);
    expect(vm.workspace!.syncState, SyncState.conflict);
    expect(vm.workspace!.classes.single.students.length, before);
    expect(vm.error, contains('xung đột'));
  });
  test('successful sync advances cloud revision only after success', () async {
    expect(await vm.sync(), true);
    expect(vm.workspace!.cloudRevision, 1);
    expect(vm.workspace!.syncState, SyncState.synced);
  });
  test('switch modes retains attendance and open link state', () async {
    final c = vm.workspace!.classes.single, m = c.meetings.first;
    await vm.start(c.id, m.id);
    await vm.mark(c.id, m.id, 'SE000001', Mark.present);
    vm.setMode(false);
    vm.setMode(true);
    expect(vm.workspace!.meeting(c.id, m.id).present, 1);
  });
}
