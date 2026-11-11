import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workspace.dart';
import '../theme/app_theme.dart';
import '../viewmodels/feature_vms.dart';
import '../viewmodels/workspace_vm.dart';
import '../widgets/app_widgets.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.classId,
    required this.meetingId,
  });
  final String classId, meetingId;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final TextEditingController search;
  @override
  void initState() {
    super.initState();
    search = TextEditingController(
      text: context.read<WorkspaceVm>().rosterQuery,
    );
    context.read<WorkspaceVm>().track('view_class');
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkspaceVm>();
    final c = vm.workspace!.classroom(widget.classId),
        m = vm.workspace!.meeting(widget.classId, widget.meetingId);
    final students = vm.roster(c);
    final linkEnabled = context.watch<ProfileVm>().config.linkEnabled;
    return AppPage(
      title: 'Điểm danh ${c.code}',
      child: PageList(
        children: [
          MeetingContext(classroom: c, meeting: m),
          AppCard(
            child: Wrap(
              spacing: AppSpace.xl,
              runSpacing: AppSpace.sm,
              children: [
                Text('Sĩ số: ${c.students.length}'),
                Text('Present: ${m.present}'),
                Text('Absent: ${m.absent}'),
                Text('Chưa ghi nhận: ${c.students.length - m.records.length}'),
              ],
            ),
          ),
          if (m.state == MeetingState.upcoming)
            AppButton(
              'Bắt đầu điểm danh',
              icon: Icons.play_arrow,
              busy: vm.busy,
              onPressed: () => vm.start(c.id, m.id),
            ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Qua link'),
                icon: Icon(Icons.link),
              ),
              ButtonSegment(
                value: true,
                label: Text('Thủ công'),
                icon: Icon(Icons.edit_outlined),
              ),
            ],
            selected: {vm.manualMode},
            onSelectionChanged: (v) => vm.setMode(v.first),
          ),
          if (!vm.manualMode) ...[
            Text(
              m.linkOpen
                  ? 'Đang nhận qua link'
                  : m.linkId == null
                  ? 'Chưa có link'
                  : 'Link tạm ngừng',
            ),
            if (!linkEnabled)
              const Text(
                'Tính năng tạo link đang tắt. Bạn có thể điểm danh thủ công.',
              ),
            AppButton(
              m.linkId == null ? 'Tạo link điểm danh' : 'Quản lý link',
              secondary: true,
              onPressed:
                  m.state == MeetingState.active &&
                      (linkEnabled || m.linkId != null)
                  ? () => Navigator.pushNamed(
                      context,
                      '/link',
                      arguments: {'classId': c.id, 'meetingId': m.id},
                    )
                  : null,
            ),
          ],
          AppField(
            label: 'Tìm tên hoặc MSSV',
            controller: search,
            onChanged: vm.search,
            suffix: IconButton(
              tooltip: 'Xóa tìm kiếm',
              onPressed: () {
                search.clear();
                vm.search('');
              },
              icon: const Icon(Icons.clear),
            ),
          ),
          VmFeedback(vm, retry: vm.receiveLinks),
          if (students.isEmpty)
            const StatePanel(
              state: LoadState.empty,
              message: 'Không tìm thấy sinh viên. Hãy thử tên hoặc MSSV khác.',
            ),
          ...students.map(
            (s) => StudentRow(
              student: s,
              record: m.records[s.id],
              manual: vm.manualMode,
              enabled: !vm.busy && m.state == MeetingState.active,
              onDetails: () => Navigator.pushNamed(
                context,
                '/student',
                arguments: {'classId': c.id, 'studentId': s.id},
              ),
              onMark: (mark) async {
                if (m.records[s.id] != null && m.records[s.id]!.mark != mark) {
                  await editAttendance(context, vm, c, m, s, mark);
                } else {
                  await vm.mark(c.id, m.id, s.id, mark);
                }
              },
            ),
          ),
          if (m.state == MeetingState.active)
            AppButton(
              'Chốt danh sách',
              busy: vm.busy,
              onPressed: () async {
                if (await confirmAction(
                  context,
                  'Chốt ${c.code} · Slot ${m.number}?',
                  '${dayKey(m.date)} · ${timeSlots[m.timeSlot - 1]}\nPresent: ${m.present}. Absent: ${m.absent}.\n${c.students.length - m.records.length} chưa ghi nhận sẽ chuyển thành Absent. Link sẽ dừng nhận.',
                  confirm: 'Đồng ý chốt',
                )) {
                  await vm.close(c.id, m.id);
                }
              },
            ),
          if (m.state == MeetingState.closed) ...[
            const Text(
              'Buổi đã chốt. Để sửa kết quả, mở Chi tiết sinh viên và nhập lý do.',
            ),
            AppButton(
              'Xuất kết quả',
              onPressed: () => Navigator.pushNamed(
                context,
                '/export',
                arguments: {'classId': c.id, 'meetingId': m.id},
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MeetingContext extends StatelessWidget {
  const MeetingContext({
    super.key,
    required this.classroom,
    required this.meeting,
  });
  final ClassRoom classroom;
  final Meeting meeting;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${classroom.subject} · ${classroom.code}',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text('Slot ${meeting.number} · ${dayKey(meeting.date)}'),
      Text(
        'Khung giờ ${meeting.timeSlot} · ${timeSlots[meeting.timeSlot - 1]}',
      ),
      const SizedBox(height: AppSpace.sm),
      Text(
        meetingLabel(meeting),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}

Future<void> editAttendance(
  BuildContext context,
  WorkspaceVm vm,
  ClassRoom c,
  Meeting m,
  Student student,
  Mark selected,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ChangeNotifierProvider.value(
      value: vm,
      child: EditAttendanceSheet(
        classroom: c,
        meeting: m,
        student: student,
        selected: selected,
      ),
    ),
  );
}

class EditAttendanceSheet extends StatefulWidget {
  const EditAttendanceSheet({
    super.key,
    required this.classroom,
    required this.meeting,
    required this.student,
    required this.selected,
  });
  final ClassRoom classroom;
  final Meeting meeting;
  final Student student;
  final Mark selected;
  @override
  State<EditAttendanceSheet> createState() => _EditAttendanceSheetState();
}

class _EditAttendanceSheetState extends State<EditAttendanceSheet> {
  final reason = TextEditingController();
  late Mark selected = widget.selected;
  String? fieldError;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkspaceVm>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Sửa điểm danh'),
            Text(
              '${widget.student.name}\n${widget.student.id} · ${widget.classroom.code}\nSlot ${widget.meeting.number} · ${dayKey(widget.meeting.date)} · ${timeSlots[widget.meeting.timeSlot - 1]}',
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              'Hiện tại: ${markLabel(widget.meeting.records[widget.student.id]?.mark)}',
            ),
            const SizedBox(height: AppSpace.lg),
            SegmentedButton<Mark>(
              segments: const [
                ButtonSegment(value: Mark.present, label: Text('Present (P)')),
                ButtonSegment(value: Mark.absent, label: Text('Absent (A)')),
              ],
              selected: {selected},
              onSelectionChanged: vm.busy
                  ? null
                  : (v) => setState(() => selected = v.first),
            ),
            const SizedBox(height: AppSpace.lg),
            AppField(
              label: 'Lý do chỉnh sửa mới',
              controller: reason,
              maxLines: 3,
              error: fieldError,
            ),
            VmFeedback(vm),
            const SizedBox(height: AppSpace.lg),
            AppButton(
              'Lưu thay đổi',
              busy: vm.busy,
              onPressed: () async {
                if (reason.text.trim().isEmpty) {
                  setState(() => fieldError = 'Vui lòng nhập lý do chỉnh sửa.');
                  return;
                }
                if (await vm.mark(
                      widget.classroom.id,
                      widget.meeting.id,
                      widget.student.id,
                      selected,
                      reason: reason.text,
                    ) &&
                    context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
            TextButton(
              onPressed: vm.busy ? null : () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkScreen extends StatelessWidget {
  const LinkScreen({super.key, required this.classId, required this.meetingId});
  final String classId, meetingId;
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LinkVm>(),
        workspace = context.watch<WorkspaceVm>();
    final c = workspace.workspace!.classroom(classId),
        m = workspace.workspace!.meeting(classId, meetingId);
    final enabled = context.watch<ProfileVm>().config.linkEnabled;
    return AppPage(
      title: 'Link điểm danh',
      child: PageList(
        children: [
          MeetingContext(classroom: c, meeting: m),
          Text(
            m.state == MeetingState.closed
                ? 'Đã kết thúc'
                : m.linkOpen
                ? 'Đang nhận qua link'
                : 'Link tạm ngừng / chưa tạo',
          ),
          const Text(
            'Sinh viên đăng nhập bằng email trong lớp rồi xác nhận. Mỗi lượt truy cập hợp lệ có 2 phút. Mở link không tự ghi Present.',
          ),
          SwitchListTile(
            title: const Text('Bật mã xác nhận 6 chữ số'),
            value: vm.withCode,
            onChanged: vm.busy || m.linkOpen ? null : vm.setCode,
          ),
          VmFeedback(vm, retry: () => vm.create(workspace, classId, meetingId)),
          VmFeedback(workspace),
          if (vm.current == null || !m.linkOpen)
            AppButton(
              m.linkId == null ? 'Tạo link' : 'Mở lại / tải link',
              busy: vm.busy,
              onPressed: enabled && m.state == MeetingState.active
                  ? () => vm.create(workspace, classId, meetingId)
                  : null,
            ),
          if (vm.current != null && m.linkOpen) ...[
            SelectableText(vm.current!.url),
            if (vm.current!.code != null)
              AppCard(
                child: Text(
                  'Mã xác nhận: ${vm.current!.code}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            AppButton('Sao chép link', secondary: true, onPressed: vm.copy),
            AppButton('Chia sẻ link', secondary: true, onPressed: vm.share),
          ],
          Text(
            'Đã ghi nhận: ${m.records.length}/${c.students.length}\nPresent: ${m.present} · Absent: ${m.absent}',
          ),
          LinearProgressIndicator(
            value: c.students.isEmpty
                ? 0
                : m.records.length / c.students.length,
          ),
          AppButton(
            'Cập nhật kết quả',
            secondary: true,
            busy: workspace.busy,
            onPressed: workspace.receiveLinks,
          ),
          if (m.linkOpen)
            AppButton(
              'Dừng nhận',
              busy: workspace.busy,
              onPressed: () => workspace.stopLink(classId, meetingId),
            ),
          const Text(
            'Dừng nhận hoặc Back không chốt buổi học. Kết quả đã ghi vẫn được giữ.',
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.classId});
  final String classId;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WorkspaceVm>().track('view_history');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkspaceVm>(),
        c = vm.workspace!.classroom(widget.classId);
    return AppPage(
      title: 'Lịch sử ${c.code}',
      child: PageList(
        children: [
          Text(
            '${c.subject} · ${c.semester}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          VmFeedback(vm),
          if (c.meetings.isEmpty)
            const StatePanel(
              state: LoadState.empty,
              message: 'Lớp chưa có buổi học. Hãy cấu hình lịch.',
            ),
          ...c.meetings.map(
            (m) => AppCard(
              onTap: () => Navigator.pushNamed(
                context,
                '/attendance',
                arguments: {'classId': c.id, 'meetingId': m.id},
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slot ${m.number} · ${dayKey(m.date)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(timeSlots[m.timeSlot - 1]),
                  Text('${meetingLabel(m)} · P ${m.present} / A ${m.absent}'),
                  const Text('Mở buổi học'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentScreen extends StatefulWidget {
  const StudentScreen({
    super.key,
    required this.classId,
    required this.studentId,
  });
  final String classId, studentId;
  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WorkspaceVm>().track('view_student');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkspaceVm>(),
        c = vm.workspace!.classroom(widget.classId);
    final s = c.students.firstWhere((s) => s.id == widget.studentId);
    final rate = vm.absenceRate(c, s.id) * 100;
    final threshold = context.watch<ProfileVm>().config.absenceWarningPercent;
    return AppPage(
      title: 'Chi tiết sinh viên',
      child: PageList(
        children: [
          Text(s.name, style: Theme.of(context).textTheme.headlineSmall),
          Text('${s.id} · ${c.code}\n${s.email}'),
          AppCard(
            child: Text(
              'Tỷ lệ vắng: ${rate.toStringAsFixed(1)}%\nSố Absent / tổng ${c.meetings.length} buổi đã lên lịch, kể cả buổi tương lai.',
            ),
          ),
          if (rate >= threshold)
            Text(
              'Cảnh báo: tỷ lệ vắng từ $threshold% trở lên.',
              style: const TextStyle(color: AppColors.error),
            ),
          VmFeedback(vm),
          ...c.meetings.map((m) {
            final record = m.records[s.id];
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slot ${m.number} · ${dayKey(m.date)}\n${timeSlots[m.timeSlot - 1]}',
                  ),
                  AttendanceStatus(record?.mark),
                  if (record?.audit.isNotEmpty ?? false)
                    ExpansionTile(
                      title: const Text('Xem ghi chú & lịch sử sửa'),
                      children: record!.audit
                          .map(
                            (a) => ListTile(
                              title: Text(
                                '${markLabel(a.before)} đến ${markLabel(a.after)}',
                              ),
                              subtitle: Text('${a.reason}\n${a.at.toLocal()}'),
                            ),
                          )
                          .toList(),
                    ),
                  if (m.state != MeetingState.upcoming)
                    TextButton(
                      onPressed: vm.busy
                          ? null
                          : () => editAttendance(
                              context,
                              vm,
                              c,
                              m,
                              s,
                              record?.mark ?? Mark.absent,
                            ),
                      child: const Text('Sửa P/A'),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
