import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workspace.dart';
import '../viewmodels/session_vm.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_vm.dart';
import '../viewmodels/feature_vms.dart';
import '../viewmodels/workspace_vm.dart';
import '../widgets/app_widgets.dart';
import 'attendance_screens.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({
    super.key,
    required this.classId,
    required this.meetingId,
  });
  final String classId, meetingId;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExportVm>(),
        workspace = context.watch<WorkspaceVm>(),
        drive = context.watch<DriveVm>();
    final c = workspace.workspace!.classroom(classId),
        m = workspace.workspace!.meeting(classId, meetingId);
    return AppPage(
      title: 'Xuất kết quả',
      child: PageList(
        children: [
          MeetingContext(classroom: c, meeting: m),
          Text('Present: ${m.present} · Absent: ${m.absent}'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'json', label: Text('JSON')),
              ButtonSegment(value: 'csv', label: Text('CSV')),
            ],
            selected: {vm.format},
            onSelectionChanged: vm.busy
                ? null
                : (v) => vm.selectFormat(v.first),
          ),
          const Text(
            'JSON dùng để trao đổi với extension desktop. CSV có thể mở trong bảng tính. Chỉ xuất một lớp, một buổi đã chốt.',
          ),
          VmFeedback(vm, retry: () => vm.generate(c, m)),
          AppButton(
            'Tạo tệp kết quả',
            busy: vm.busy,
            onPressed: () => vm.generate(c, m),
          ),
          if (vm.generated != null) ...[
            AppCard(
              child: Text(
                '${vm.generated!.name}\n${vm.generated!.bytes.length} bytes',
              ),
            ),
            AppButton('Lưu trên thiết bị', busy: vm.busy, onPressed: vm.save),
            AppButton(
              'Chia sẻ tệp',
              secondary: true,
              onPressed: vm.busy ? null : vm.share,
            ),
            if (vm.savedPath != null) SelectableText('Đã lưu: ${vm.savedPath}'),
            const Divider(),
            const SectionTitle('Cloud Storage'),
            LinearProgressIndicator(value: vm.progress),
            Text('Tiến độ: ${(vm.progress * 100).round()}%'),
            AppButton(
              'Upload Cloud Storage',
              busy: vm.busy,
              onPressed: () => vm.upload(workspace.uid),
            ),
            if (vm.downloadUrl != null) SelectableText(vm.downloadUrl!),
            const SectionTitle('Google Drive (tùy chọn)'),
            VmFeedback(drive),
            Text('Trạng thái: ${drive.status}'),
            if (!drive.driveService.connected)
              AppButton(
                'Kết nối Drive',
                secondary: true,
                busy: drive.busy,
                onPressed: drive.connect,
              )
            else
              AppButton(
                'Lưu tệp lên Drive',
                secondary: true,
                busy: drive.busy,
                onPressed: () => drive.upload(vm.generated!),
              ),
            if (drive.lastUrl != null) SelectableText(drive.lastUrl!),
          ],
        ],
      ),
    );
  }
}

class DriveScreen extends StatelessWidget {
  const DriveScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DriveVm>(),
        workspace = context.watch<WorkspaceVm>();
    final hasClasses = workspace.workspace?.visibleClasses.isNotEmpty ?? false;
    return AppPage(
      title: 'Google Drive & đồng bộ',
      bottom: !hasClasses
          ? null
          : AppNavigation(
              index: 1,
              onSelect: (i) {
                if (i == 0) Navigator.popUntil(context, (r) => r.isFirst);
              },
            ),
      child: PageList(
        children: [
          const Icon(
            Icons.cloud_outlined,
            size: AppSpace.touch,
            color: AppColors.primary,
          ),
          const SectionTitle('Dữ liệu luôn ở trên máy'),
          const Text(
            'Drive là bản lưu tùy chọn. Kết nối Drive không tự tạo lớp hoặc xác minh email nhận diện workspace.',
          ),
          AppCard(
            child: Text(
              'Firestore: ${workspace.workspace?.syncState.name ?? 'localOnly'}\nDrive: ${vm.status}',
            ),
          ),
          VmFeedback(workspace, retry: workspace.sync),
          VmFeedback(vm, retry: vm.connect),
          AppButton(
            vm.driveService.connected
                ? 'Tải lại danh sách Drive'
                : 'Kết nối Google Drive',
            busy: vm.busy,
            onPressed: vm.connect,
          ),
          const Text(
            'Quyền drive.file chỉ đọc các tệp đã được cấp quyền cho ứng dụng. Bạn cũng có thể chọn file từ Drive trong trình chọn tệp Android.',
          ),
          AppButton(
            'Chọn markbook qua trình chọn tệp',
            secondary: true,
            onPressed: () => Navigator.pushNamed(context, '/import'),
          ),
          if (vm.driveService.connected && vm.sources.isEmpty)
            const StatePanel(
              state: LoadState.empty,
              message: 'Chưa có markbook được cấp quyền trên Drive. Chọn file qua trình chọn tệp để import.',
            ),
          ...vm.sources.map(
            (file) => AppCard(
              child: ListTile(
                title: Text(file.name ?? 'Markbook'),
                subtitle: const Text('Nhập dữ liệu từ Drive'),
                trailing: const Icon(Icons.download_outlined),
                onTap: vm.busy
                    ? null
                    : () async {
                        final picked = await vm.download(file.id!, file.name!);
                        if (picked != null && context.mounted) {
                          context.read<ImportVm>().useFile(picked);
                          Navigator.pushNamed(context, '/import');
                        }
                      },
              ),
            ),
          ),
          AppButton(
            'Đồng bộ workspace lên Firestore',
            secondary: true,
            busy: workspace.busy,
            onPressed: workspace.workspace == null ? null : workspace.sync,
          ),
          const Text(
            'Nếu có xung đột, ứng dụng giữ bản trên máy và dừng đồng bộ để bạn kiểm tra. Không tự ghi đè dữ liệu khác.',
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileVm>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileVm>(),
        auth = context.watch<AuthVm>(),
        workspace = context.watch<WorkspaceVm>();
    return AppPage(
      title: 'Hồ sơ & Firebase',
      child: PageList(
        children: [
          AppCard(child: Text('Giảng viên\n${auth.identity?.email ?? ''}')),
          VmFeedback(vm),
          VmFeedback(auth),
          const SectionTitle('Remote Config'),
          Text(
            'attendance_link_enabled: ${vm.config.linkEnabled}\nabsence_warning_percent: ${vm.config.absenceWarningPercent}',
          ),
          const Text(
            'Bật/tắt tạo link tại S04 và thay ngưỡng cảnh báo tỷ lệ vắng tại S07. Giá trị mặc định: true và 20%.',
          ),
          AppButton(
            'Tải cấu hình mới',
            busy: vm.busy,
            onPressed: vm.refreshConfig,
          ),
          const SectionTitle('Trung tâm thông báo'),
          AppButton(
            'Cho phép thông báo',
            secondary: true,
            busy: vm.busy,
            onPressed: vm.requestPermission,
          ),
          if (vm.items.isEmpty)
            const StatePanel(
              state: LoadState.empty,
              message: 'Chưa nhận thông báo nào.',
            ),
          ...vm.items.map(
            (item) => AppCard(
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(item.body),
                onTap: () {
                  final target = workspace.notificationTarget(item);
                  if (target != null) {
                    Navigator.pushNamed(
                      context,
                      '/attendance',
                      arguments: target,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Thông báo không trỏ đến buổi học trên thiết bị này.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
          TextButton(
            onPressed: vm.loadNotifications,
            child: const Text('Tải lại thông báo'),
          ),
          const SectionTitle('Xuất tệp & Cloud Storage'),
          const Text(
            'Chọn buổi đã chốt từ lịch sử lớp để xuất đúng kết quả đang xem.',
          ),
          AppButton(
            'Mở lịch lớp',
            secondary: true,
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
          const SectionTitle('Crashlytics demo'),
          const Text(
            'Lỗi đã xử lý được ghi từ các luồng thật như import tệp lỗi hoặc đồng bộ thất bại. Crash thử nghiệm sẽ đóng ứng dụng.',
          ),
          if (!kIsWeb)
            AppButton(
              'Gây crash thử nghiệm',
              secondary: true,
              onPressed: () async {
                if (await confirmAction(
                  context,
                  'Gây crash thử nghiệm?',
                  'Ứng dụng sẽ đóng ngay. Chỉ dùng khi thu thập bằng chứng Crashlytics.',
                  confirm: 'Gây crash',
                )) {
                  vm.crash();
                }
              },
            ),
          AppButton(
            'Đăng xuất',
            secondary: true,
            busy: auth.busy,
            onPressed: workspace.busy
                ? null
                : () async {
                    final session = context.read<SessionVm>();
                    if (await confirmAction(
                      context,
                      'Đăng xuất?',
                      'Dữ liệu cục bộ và thông báo của tài khoản sẽ được xóa. Hãy đồng bộ hoặc xuất tệp cần giữ trước khi tiếp tục.',
                      confirm: 'Đăng xuất',
                    )) {
                      await session.signOut();
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class StudentCheckInScreen extends StatefulWidget {
  const StudentCheckInScreen({super.key});
  @override
  State<StudentCheckInScreen> createState() => _StudentCheckInScreenState();
}

class _StudentCheckInScreenState extends State<StudentCheckInScreen> {
  final code = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StudentCheckInVm>().begin();
    });
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StudentCheckInVm>();
    return AppPage(
      title: 'Xác nhận điểm danh',
      child: PageList(
        children: [
          const Text(
            'Kiểm tra đúng lớp và buổi học trước khi gửi. Bạn có 2 phút cho lượt này; mở lượt mới nếu hết hạn.',
          ),
          VmFeedback(vm, retry: vm.begin),
          if (vm.busy) const LinearProgressIndicator(),
          if (vm.visit != null) ...[
            AppCard(
              child: Text(
                '${vm.visit!['subject']} · ${vm.visit!['classCode']}\nSlot ${vm.visit!['slot']} · ${vm.visit!['date']}\n${vm.visit!['studentId']} · ${vm.visit!['name']}',
              ),
            ),
            if (vm.visit!['codeEnabled'] == true)
              AppField(
                label: 'Mã xác nhận 6 chữ số',
                controller: code,
                keyboardType: TextInputType.number,
              ),
            if (!vm.submitted)
              AppButton(
                'Xác nhận tôi có mặt',
                busy: vm.busy,
                onPressed: () => vm.submit(code.text),
              ),
          ],
          AppButton(
            'Bắt đầu lượt mới',
            secondary: true,
            busy: vm.busy,
            onPressed: vm.begin,
          ),
        ],
      ),
    );
  }
}
