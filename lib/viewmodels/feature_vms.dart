import 'dart:async';

import 'package:googleapis/drive/v3.dart' as drive;

import '../models/workspace.dart';
import '../services/attendance_link_service.dart';
import '../services/cloud_file_service.dart';
import '../services/config_service.dart';
import '../services/drive_service.dart';
import '../services/file_service.dart';
import '../services/markbook_parser.dart';
import '../services/notification_service.dart';
import '../services/telemetry_service.dart';
import 'base_vm.dart';
import 'workspace_vm.dart';

class ImportVm extends BaseVm {
  ImportVm(this.files, this.parser, TelemetryService telemetry)
    : super(telemetry);
  final FileService files;
  final MarkbookParser parser;
  PickedMarkbook? selected;
  List<ClassRoom> preview = [];
  void invalidatePreview() {
    if (preview.isNotEmpty) {
      preview = [];
      changed();
    }
  }

  Future<bool> pick() => perform('pick_markbook', () async {
    final result = await files.pickMarkbook();
    if (result != null) {
      selected = result;
      preview = [];
      state = LoadState.data;
    } else {
      message = 'Đã hủy chọn tệp.';
    }
  });
  void useFile(PickedMarkbook file) {
    selected = file;
    preview = [];
    state = LoadState.data;
    changed();
  }

  Future<bool> inspect(
    String semester,
    DateTime start,
    int weeks,
    List<ScheduleRule> rules,
  ) => perform('parse_markbook', () async {
    if (selected == null) throw const AppFailure('Hãy chọn tệp ODS hoặc XLSX.');
    preview = parser.parse(
      selected!.bytes,
      selected!.name,
      semester: semester,
      start: start,
      weeks: weeks,
      rules: rules,
    );
    state = LoadState.data;
  }, loading: true);
}

class LinkVm extends BaseVm {
  LinkVm(this.links, this.files, TelemetryService telemetry) : super(telemetry);
  final AttendanceLinkService links;
  final FileService files;
  LinkSession? current;
  bool withCode = false;
  void setCode(bool value) {
    withCode = value;
    changed();
  }

  Future<bool> create(
    WorkspaceVm workspace,
    String classId,
    String meetingId,
  ) => perform('create_link', () async {
    final c = workspace.workspace!.classroom(classId),
        m = workspace.workspace!.meeting(classId, meetingId);
    final result = await links.create(c, m, withCode);
    await workspace.attachLink(classId, meetingId, result);
    current = result;
    state = LoadState.data;
    await telemetry.event('create_attendance_link', {
      'code_enabled': withCode ? 1 : 0,
    });
  });
  Future<bool> copy() => perform('copy_link', () async {
    await files.copy(current!.url);
    message = 'Đã sao chép link điểm danh.';
  });
  Future<bool> share() =>
      perform('share_link', () => files.shareLink(current!.url));
}

class ExportVm extends BaseVm {
  ExportVm(this.exports, this.files, this.cloud, TelemetryService telemetry)
    : super(telemetry);
  final ExportService exports;
  final FileService files;
  final CloudFileService cloud;
  GeneratedFile? generated;
  String format = 'json';
  String? savedPath, downloadUrl;
  double progress = 0;
  void selectFormat(String value) {
    format = value;
    generated = null;
    savedPath = null;
    downloadUrl = null;
    changed();
  }

  Future<bool> generate(ClassRoom c, Meeting m) =>
      perform('export_report', () async {
        generated = exports.generate(c, m, format);
        state = LoadState.data;
        await telemetry.event('export_report', {
          'format': format,
          'byte_count': generated!.bytes.length,
        });
      });
  Future<bool> save() => perform('save_export', () async {
    final result = await files.save(generated!);
    if (result == null) {
      message = 'Đã hủy lưu tệp.';
      return;
    }
    savedPath = result;
    message = 'Đã lưu trên máy: ${generated!.name}';
  });
  Future<bool> share() =>
      perform('share_export', () => files.share(generated!));
  Future<bool> upload(String uid) => perform('upload_report', () async {
    progress = 0;
    downloadUrl = await cloud.upload(uid, generated!, (value) {
      progress = value;
      changed();
    });
    message = 'Đã tải lên Cloud Storage.';
    await telemetry.event('upload_report', {
      'byte_count': generated!.bytes.length,
      'destination': 'storage',
    });
  });
}

class DriveVm extends BaseVm {
  DriveVm(this.driveService, TelemetryService telemetry) : super(telemetry);
  final DriveService driveService;
  List<drive.File> sources = [];
  String status = 'local-only';
  String? lastUrl;
  Future<bool> connect() => perform('drive_connect', () async {
    await driveService.connect();
    sources = await driveService.markbooks();
    state = sources.isEmpty ? LoadState.empty : LoadState.data;
    message = 'Đã kết nối Drive. Chỉ hiển thị tệp được cấp quyền cho ứng dụng.';
  }, loading: true);
  Future<PickedMarkbook?> download(String id, String name) async {
    PickedMarkbook? result;
    await perform('drive_download', () async {
      result = await driveService.download(id, name);
    });
    return result;
  }

  Future<bool> upload(GeneratedFile file) => perform('drive_upload', () async {
    status = 'pendingSync';
    changed();
    try {
      lastUrl = await driveService.upload(file);
      status = 'synced';
    } on AppFailure catch (e) {
      if (e.message == 'conflict') status = 'conflict';
      rethrow;
    }
    await telemetry.event('upload_report', {
      'byte_count': file.bytes.length,
      'destination': 'drive',
    });
  });
}

class ProfileVm extends BaseVm {
  ProfileVm(
    this.uid,
    this.configService,
    this.notifications,
    TelemetryService telemetry,
  ) : super(telemetry) {
    _subscription = notifications.received.listen(
      (_) => unawaited(loadNotifications()),
    );
  }
  final String uid;
  final ConfigService configService;
  final NotificationService notifications;
  AppConfig config = const AppConfig();
  List<AppNotification> items = [];
  late final StreamSubscription<void> _subscription;
  Future<bool> initialize() => perform('profile_initialize', () async {
    await notifications.initialize(uid);
    items = await notifications.list(uid);
    state = items.isEmpty ? LoadState.empty : LoadState.data;
  });
  Future<bool> refreshConfig() => perform('remote_config', () async {
    config = await configService.refresh();
    message = 'Đã áp dụng cấu hình. Chu kỳ tải tối thiểu: 1 phút.';
  });
  Future<bool> loadNotifications() => perform('notifications_load', () async {
    items = await notifications.list(uid);
    state = items.isEmpty ? LoadState.empty : LoadState.data;
  });
  Future<bool> requestPermission() =>
      perform('notifications_permission', () async {
        message = await notifications.requestPermission();
      });
  void crash() => telemetry.testCrash();
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class StudentCheckInVm extends BaseVm {
  StudentCheckInVm(this.links, this.sessionId, TelemetryService telemetry)
    : super(telemetry);
  final AttendanceLinkService links;
  final String sessionId;
  Map<String, dynamic>? visit;
  bool submitted = false;
  Future<bool> begin() => perform('student_visit', () async {
    visit = await links.beginStudentVisit(sessionId);
    state = LoadState.data;
    submitted = false;
  }, loading: true);
  Future<bool> submit(String code) => perform('student_submit', () async {
    await links.submitStudent(sessionId, code.trim());
    submitted = true;
    message = 'Đã gửi điểm danh. Giảng viên sẽ nhận kết quả.';
  });
}
