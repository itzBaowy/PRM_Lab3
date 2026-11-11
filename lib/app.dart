import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/attendance_screens.dart';
import 'screens/cloud_screens.dart';
import 'screens/workspace_screens.dart';
import 'services/attendance_engine.dart';
import 'services/attendance_link_service.dart';
import 'services/auth_service.dart';
import 'services/cloud_file_service.dart';
import 'services/cloud_workspace_service.dart';
import 'services/config_service.dart';
import 'services/drive_service.dart';
import 'services/file_service.dart';
import 'services/local_store.dart';
import 'services/markbook_parser.dart';
import 'services/notification_service.dart';
import 'services/telemetry_service.dart';
import 'theme/app_theme.dart';
import 'viewmodels/auth_vm.dart';
import 'viewmodels/feature_vms.dart';
import 'viewmodels/workspace_vm.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key, required this.telemetry});
  final TelemetryService telemetry;
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<TelemetryService>.value(value: telemetry),
      Provider(create: (_) => FileService()),
      ChangeNotifierProvider(
        create: (_) =>
            AuthVm(FirebaseAuthService(FirebaseAuth.instance), telemetry),
      ),
    ],
    child: MaterialApp(
      title: 'FAP Attendance',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Consumer<AuthVm>(
        builder: (context, auth, _) => auth.identity == null
            ? const SignInScreen()
            : SignedInScope(
                key: ValueKey(auth.identity!.uid),
                identity: auth.identity!,
              ),
      ),
    ),
  );
}

class SignedInScope extends StatefulWidget {
  const SignedInScope({super.key, required this.identity});
  final Identity identity;
  @override
  State<SignedInScope> createState() => _SignedInScopeState();
}

class _SignedInScopeState extends State<SignedInScope> {
  final navigator = GlobalKey<NavigatorState>();
  late final WorkspaceVm workspace;
  late final ProfileVm profile;
  late final ImportVm importer;
  late final DriveVm driveVm;
  late final DriveService drive;
  late final NotificationService notifications;
  late final AttendanceLinkService links;
  StreamSubscription<AppNotification>? opened;
  @override
  void initState() {
    super.initState();
    final telemetry = context.read<TelemetryService>();
    final db = FirebaseFirestore.instance;
    final engine = AttendanceEngine();
    links = AttendanceLinkService(
      db,
      FirebaseAuth.instance,
      const String.fromEnvironment('ATTENDANCE_BASE_URL'),
    );
    notifications = NotificationService(FirebaseMessaging.instance, db);
    workspace = WorkspaceVm(
      uid: widget.identity.uid,
      store: LocalWorkspaceStore(),
      cloud: FirestoreWorkspaceService(db),
      engine: engine,
      links: links,
      telemetry: telemetry,
    );
    profile = ProfileVm(
      widget.identity.uid,
      ConfigService(FirebaseRemoteConfig.instance),
      notifications,
      telemetry,
    );
    importer = ImportVm(
      context.read<FileService>(),
      MarkbookParser(engine),
      telemetry,
    );
    drive = DriveService(widget.identity.uid);
    driveVm = DriveVm(drive, telemetry);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await workspace.load();
      if (!mounted) return;
      opened = notifications.opened.listen((notice) {
        final target = notificationTarget(workspace, notice);
        if (target != null) {
          navigator.currentState?.pushNamed('/attendance', arguments: target);
        }
      });
      if (!kIsWeb) await profile.initialize();
      if (mounted) await profile.refreshConfig();
    });
  }

  @override
  void dispose() {
    opened?.cancel();
    notifications.stop();
    workspace.dispose();
    profile.dispose();
    importer.dispose();
    driveVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: workspace),
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider.value(value: importer),
      ChangeNotifierProvider.value(value: driveVm),
      Provider.value(value: drive),
      Provider.value(value: notifications),
    ],
    child: Navigator(
      key: navigator,
      onGenerateRoute: (settings) {
        final a = (settings.arguments as Map<String, String>?) ?? {};
        final telemetry = context.read<TelemetryService>(),
            files = context.read<FileService>();
        final Widget screen;
        final sessionId = Uri.base.queryParameters['session'];
        if (sessionId != null && settings.name == '/') {
          screen = ChangeNotifierProvider(
            create: (_) => StudentCheckInVm(links, sessionId, telemetry),
            child: const StudentCheckInScreen(),
          );
        } else {
          screen = switch (settings.name) {
            '/import' => const ImportScreen(),
            '/schedule' => ScheduleScreen(classId: a['classId']!),
            '/attendance' => AttendanceScreen(
              classId: a['classId']!,
              meetingId: a['meetingId']!,
            ),
            '/history' => HistoryScreen(classId: a['classId']!),
            '/student' => StudentScreen(
              classId: a['classId']!,
              studentId: a['studentId']!,
            ),
            '/link' => ChangeNotifierProvider(
              create: (_) => LinkVm(links, files, telemetry),
              child: LinkScreen(
                classId: a['classId']!,
                meetingId: a['meetingId']!,
              ),
            ),
            '/export' => ChangeNotifierProvider(
              create: (_) => ExportVm(
                ExportService(),
                files,
                CloudFileService(FirebaseStorage.instance),
                telemetry,
              ),
              child: ExportScreen(
                classId: a['classId']!,
                meetingId: a['meetingId']!,
              ),
            ),
            '/drive' => const DriveScreen(),
            '/profile' => const ProfileScreen(),
            _ => const HomeScreen(),
          };
        }
        return MaterialPageRoute(settings: settings, builder: (_) => screen);
      },
    ),
  );
}
