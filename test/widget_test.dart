import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:fap_attendance/models/workspace.dart';
import 'package:fap_attendance/screens/attendance_screens.dart';
import 'package:fap_attendance/screens/workspace_screens.dart';
import 'package:fap_attendance/services/attendance_engine.dart';
import 'package:fap_attendance/services/config_service.dart';
import 'package:fap_attendance/services/notification_service.dart';
import 'package:fap_attendance/theme/app_theme.dart';
import 'package:fap_attendance/viewmodels/feature_vms.dart';
import 'package:fap_attendance/viewmodels/workspace_vm.dart';
import 'package:fap_attendance/widgets/app_widgets.dart';
import 'package:fap_attendance/widgets/frozen_week_table.dart';

import 'support.dart';

class MockConfig extends Mock implements ConfigService {}

class MockNotifications extends Mock implements NotificationService {}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [360.0, 412.0]) {
    testWidgets(
      'roster ${width.toInt()}dp preserves long names and P/A selection',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final telemetry = MemoryTelemetry(),
            store = MemoryStore()..value = fixture(longNames: true);
        final vm = WorkspaceVm(
          uid: 'test-owner',
          store: store,
          cloud: MemoryCloud(),
          engine: AttendanceEngine(now: () => testDay),
          links: null,
          telemetry: telemetry,
        );
        await vm.load();
        final c = vm.workspace!.classes.single, m = c.meetings.first;
        await vm.start(c.id, m.id);
        final notices = MockNotifications();
        when(() => notices.received).thenAnswer((_) => const Stream.empty());
        final profile = ProfileVm(
          'test-owner',
          MockConfig(),
          notices,
          telemetry,
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: vm),
              ChangeNotifierProvider.value(value: profile),
            ],
            child: MaterialApp(
              theme: buildAppTheme(),
              home: AttendanceScreen(classId: c.id, meetingId: m.id),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(AttendanceScreen),
          matchesGoldenFile('../evidence/ui/attendance-${width.toInt()}.png'),
        );
        await tester.scrollUntilVisible(
          find.text('P · Có mặt').first,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('P · Có mặt').first);
        await tester.pumpAndSettle();
        expect(vm.workspace!.meeting(c.id, m.id).present, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        vm.dispose();
        profile.dispose();
      },
    );
  }
  testWidgets(
    'edit sheet rejects blank reason and cancel leaves original data',
    (tester) async {
      final store = MemoryStore()..value = fixture();
      final telemetry = MemoryTelemetry();
      final vm = WorkspaceVm(
        uid: 'test-owner',
        store: store,
        cloud: MemoryCloud(),
        engine: AttendanceEngine(now: () => testDay),
        links: null,
        telemetry: telemetry,
      );
      await vm.load();
      final c = vm.workspace!.classes.single, m = c.meetings.first;
      await vm.start(c.id, m.id);
      await vm.mark(c.id, m.id, 'SE000001', Mark.present);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: vm,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: AppButton(
                  'Sửa',
                  onPressed: () => editAttendance(
                    context,
                    vm,
                    c,
                    vm.workspace!.meeting(c.id, m.id),
                    c.students.first,
                    Mark.absent,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sửa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập lý do chỉnh sửa.'), findsOneWidget);
      expect(vm.workspace!.meeting(c.id, m.id).present, 1);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(vm.workspace!.meeting(c.id, m.id).present, 1);
      await tester.pumpWidget(const SizedBox());
      vm.dispose();
    },
  );
  testWidgets(
    'calendar keeps time labels fixed and synchronizes horizontal rows',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: FrozenWeekTable(
                labels: const [Text('Khung giờ'), Text('07:00–09:15')],
                rows: [
                  List.generate(7, (i) => Text('Day $i')),
                  List.generate(7, (i) => Text('Meeting $i\nDetails')),
                ],
              ),
            ),
          ),
        ),
      );
      final before = tester.getTopLeft(
        find.byKey(const ValueKey('frozen-slot-1')),
      );
      await tester.drag(
        find.byKey(const ValueKey('week-row-1')),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('frozen-slot-1'))),
        before,
      );
      final scrolls = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .where((w) => w.scrollDirection == Axis.horizontal)
          .toList();
      expect(scrolls[0].controller!.offset, scrolls[1].controller!.offset);
      expect(scrolls[0].controller!.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('home calendar screenshot has no overflow at 360dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = WorkspaceVm(
      uid: 'test-owner',
      store: MemoryStore()..value = fixture(),
      cloud: MemoryCloud(),
      engine: AttendanceEngine(now: () => testDay),
      links: null,
      telemetry: MemoryTelemetry(),
    );
    await vm.load();
    vm.selectWeek(testDay);
    vm.setCalendar(true);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('../evidence/ui/home-calendar-360.png'),
    );
    await tester.pumpWidget(const SizedBox());
    vm.dispose();
  });
}
