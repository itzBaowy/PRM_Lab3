import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workspace.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_vm.dart';
import '../viewmodels/feature_vms.dart';
import '../viewmodels/workspace_vm.dart';
import '../widgets/app_widgets.dart';
import '../widgets/frozen_week_table.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthVm>();
    return AppPage(
      title: 'FAP Attendance',
      child: PageList(
        children: [
          const SizedBox(height: AppSpace.xxl),
          const Icon(
            Icons.fact_check_outlined,
            size: AppSpace.touch * 2,
            color: AppColors.primary,
          ),
          Text(
            'Điểm danh rõ ràng.\nLớp học trong tầm tay.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Đăng nhập để quản lý lịch dạy, ghi nhận điểm danh và lưu kết quả của bạn.',
          ),
          AppButton(
            'Đăng nhập bằng Google',
            icon: Icons.login,
            busy: vm.busy,
            onPressed: vm.signIn,
          ),
          VmFeedback(vm, retry: vm.signIn),
          const Text(
            'FAP Attendance Mobile\nPRM393 · Nhóm 3',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final TextEditingController email;
  @override
  void initState() {
    super.initState();
    email = TextEditingController(
      text: context.read<WorkspaceVm>().workspace?.email.isNotEmpty == true
          ? context.read<WorkspaceVm>().workspace!.email
          : context.read<AuthVm>().identity?.email,
    );
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkspaceVm>();
    return AppPage(
      title: 'Bắt đầu workspace',
      actions: [
        IconButton(
          tooltip: 'Hồ sơ',
          onPressed: () => Navigator.pushNamed(context, '/profile'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
      child: PageList(
        children: [
          Text(
            'Chào giảng viên!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Nhập markbook để tạo danh sách lớp và lịch dạy của học kỳ.',
          ),
          AppField(
            label: 'Email nhận diện giảng viên',
            controller: email,
            keyboardType: TextInputType.emailAddress,
          ),
          const Text(
            'Email này dùng trong workspace. Tài khoản Google đang đăng nhập xác định quyền truy cập dữ liệu.',
          ),
          VmFeedback(vm),
          AppButton(
            'Chọn markbook ODS / XLSX',
            icon: Icons.upload_file,
            busy: vm.busy,
            onPressed: () async {
              if (await vm.setEmail(email.text) && context.mounted) {
                Navigator.pushNamed(context, '/import');
              }
            },
          ),
          AppButton(
            'Kết nối Google Drive',
            secondary: true,
            icon: Icons.cloud_outlined,
            onPressed: () => Navigator.pushNamed(context, '/drive'),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  void open(BuildContext context, ClassRoom c, Meeting m) =>
      Navigator.pushNamed(
        context,
        '/attendance',
        arguments: {'classId': c.id, 'meetingId': m.id},
      );
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkspaceVm>();
    if (vm.state == LoadState.loading) {
      return const AppPage(
        title: 'Lịch tuần & lớp',
        child: StatePanel(state: LoadState.loading),
      );
    }
    if (vm.workspace == null) {
      return AppPage(
        title: 'Lịch tuần & lớp',
        child: StatePanel(
          state: LoadState.error,
          message: vm.error ?? 'Chưa đọc được workspace.',
          onRetry: vm.load,
        ),
      );
    }
    if (vm.workspace!.visibleClasses.isEmpty) return const WorkspaceScreen();
    return AppPage(
      title: 'Lịch tuần & lớp',
      constrain: false,
      actions: [
        IconButton(
          tooltip: 'Import markbook',
          onPressed: () => Navigator.pushNamed(context, '/import'),
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'Hồ sơ và Firebase',
          onPressed: () => Navigator.pushNamed(context, '/profile'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
      bottom: AppNavigation(
        index: 0,
        onSelect: (index) {
          if (index == 1) Navigator.pushNamed(context, '/drive');
        },
      ),
      child: PageList(
        children: [
          Text(
            vm.workspace!.visibleClasses
                .map((c) => c.semester)
                .toSet()
                .join(' · '),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${dayKey(vm.week)} → ${dayKey(vm.week.add(const Duration(days: 6)))}',
                ),
              ),
              IconButton(
                tooltip: 'Tuần trước',
                onPressed: () => vm.moveWeek(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Tuần sau',
                onPressed: () => vm.moveWeek(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              TextButton(
                onPressed: () => vm.selectWeek(DateTime.now()),
                child: const Text('Tuần này'),
              ),
              TextButton(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: vm.week,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) vm.selectWeek(date);
                },
                child: const Text('Chọn tuần'),
              ),
            ],
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.view_list_outlined),
                label: Text('Danh sách lớp'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.calendar_month_outlined),
                label: Text('Lịch tuần'),
              ),
            ],
            selected: {vm.calendarMode},
            onSelectionChanged: (values) => vm.setCalendar(values.first),
          ),
          VmFeedback(vm, retry: vm.sync),
          if (vm.calendarMode)
            _WeekGrid(vm: vm, open: (c, m) => open(context, c, m))
          else
            ...vm.workspace!.visibleClasses.map(
              (c) => _ClassCard(classroom: c, vm: vm),
            ),
          if (vm.calendarMode)
            ExpansionTile(
              title: const Text('Quản lý tất cả lớp'),
              children: vm.workspace!.visibleClasses
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.lg),
                      child: _ClassCard(classroom: c, vm: vm),
                    ),
                  )
                  .toList(),
            ),
          AppButton(
            'Đồng bộ Firestore',
            secondary: true,
            busy: vm.busy,
            onPressed: vm.sync,
            icon: Icons.sync,
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.classroom, required this.vm});
  final ClassRoom classroom;
  final WorkspaceVm vm;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${classroom.subject} · ${classroom.code}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          '${classroom.students.length} sinh viên · ${classroom.meetings.length} buổi học',
        ),
        const SizedBox(height: AppSpace.sm),
        AppButton(
          'Mở lịch sử & buổi học',
          onPressed: () => Navigator.pushNamed(
            context,
            '/history',
            arguments: {'classId': classroom.id},
          ),
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: () => Navigator.pushNamed(
                context,
                '/schedule',
                arguments: {'classId': classroom.id},
              ),
              child: const Text('Cấu hình lịch'),
            ),
            TextButton(
              onPressed: vm.busy
                  ? null
                  : () async {
                      if (await confirmAction(
                        context,
                        'Xóa lớp ${classroom.code}?',
                        'Lớp sẽ được lưu trữ trên thiết bị và ẩn khỏi lịch. Giữ nguyên tệp markbook nguồn.',
                        confirm: 'Lưu trữ lớp',
                      )) {
                        await vm.archive(classroom.id);
                      }
                    },
              child: const Text('Xóa lớp'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.vm, required this.open});
  final WorkspaceVm vm;
  final void Function(ClassRoom, Meeting) open;
  @override
  Widget build(BuildContext context) {
    final grid = vm.weekGrid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vuốt ngang để xem đủ Thứ Hai – Chủ Nhật →'),
        if (vm.weekEmpty)
          StatePanel(
            state: LoadState.empty,
            message: 'Chưa có lịch dạy trong tuần này. Chọn tuần khác.',
            actionLabel: 'Về tuần này',
            onRetry: () => vm.selectWeek(DateTime.now()),
          ),
        FrozenWeekTable(
          labels: [
            const Text('Khung giờ'),
            for (var slot = 0; slot < 4; slot++)
              Text('${slot + 1}\n${timeSlots[slot]}'),
          ],
          rows: [
            [
              for (var day = 0; day < 7; day++)
                Container(
                  color: vm.isToday(day) ? AppColors.soft : AppColors.surface,
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: Text(
                    '${['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][day]}\n${dayKey(vm.week.add(Duration(days: day)))}${vm.isToday(day) ? '\nHôm nay' : ''}',
                  ),
                ),
            ],
            for (final row in grid)
              [
                for (final cell in row)
                  Column(
                    children: cell.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(AppSpace.lg),
                              child: Text('—'),
                            ),
                          ]
                        : [
                            for (final item in cell)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpace.sm,
                                ),
                                child: MeetingCell(
                                  classroom: item.classroom,
                                  meeting: item.meeting,
                                  onTap: () =>
                                      open(item.classroom, item.meeting),
                                ),
                              ),
                          ],
                  ),
              ],
          ],
        ),
      ],
    );
  }
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final semester = TextEditingController(),
      weeks = TextEditingController(text: '10');
  DateTime start = dateOnly(DateTime.now());
  int slots = 1,
      weekday = DateTime.now().weekday,
      secondDay = DateTime.now().weekday % 7 + 1,
      timeSlot = 1;
  @override
  void dispose() {
    semester.dispose();
    weeks.dispose();
    super.dispose();
  }

  List<ScheduleRule> get rules => [
    ScheduleRule(weekday, timeSlot),
    if (slots == 2) ScheduleRule(secondDay, timeSlot),
  ];
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ImportVm>(),
        workspace = context.watch<WorkspaceVm>();
    return AppPage(
      title: 'Import markbook',
      child: PageList(
        children: [
          const SectionTitle('Dữ liệu cho học kỳ'),
          const Text(
            'Header bắt buộc: class_code, subject, student_id, student_name, email. Mỗi dòng là một sinh viên của một lớp.',
          ),
          AppButton(
            vm.selected?.name ?? 'Chọn ODS / XLSX',
            icon: Icons.description_outlined,
            secondary: true,
            busy: vm.busy,
            onPressed: vm.pick,
          ),
          AppField(
            label: 'Học kỳ',
            controller: semester,
            hint: 'Ví dụ: Fall 2026',
          ),
          AppField(
            label: 'Số tuần (1–52)',
            controller: weeks,
            keyboardType: TextInputType.number,
          ),
          AppButton(
            'Ngày bắt đầu: ${dayKey(start)}',
            secondary: true,
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: start,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) setState(() => start = date);
            },
          ),
          _NumberSelect(
            label: 'Slot mỗi tuần',
            value: slots,
            values: const [1, 2],
            onChanged: (v) => setState(() => slots = v),
          ),
          _NumberSelect(
            label: 'Ngày học (1=Thứ Hai, 7=Chủ Nhật)',
            value: weekday,
            values: const [1, 2, 3, 4, 5, 6, 7],
            onChanged: (v) => setState(() => weekday = v),
          ),
          if (slots == 2)
            _NumberSelect(
              label: 'Ngày học thứ hai',
              value: secondDay,
              values: const [1, 2, 3, 4, 5, 6, 7],
              onChanged: (v) => setState(() => secondDay = v),
            ),
          _NumberSelect(
            label: 'Khung giờ',
            value: timeSlot,
            values: const [1, 2, 3, 4],
            onChanged: (v) => setState(() => timeSlot = v),
          ),
          VmFeedback(
            vm,
            retry: () => vm.inspect(
              semester.text,
              start,
              int.tryParse(weeks.text) ?? 0,
              rules,
            ),
          ),
          AppButton(
            'Kiểm tra & xem trước',
            busy: vm.busy,
            onPressed: () => vm.inspect(
              semester.text,
              start,
              int.tryParse(weeks.text) ?? 0,
              rules,
            ),
          ),
          if (vm.preview.isNotEmpty) ...[
            const SectionTitle('Xác nhận dữ liệu'),
            ...vm.preview.map(
              (c) => AppCard(
                child: Text(
                  '${c.subject} · ${c.code}\n${c.students.length} sinh viên · ${c.meetings.length} buổi\n${c.students.take(3).map((s) => '${s.id} · ${s.name}').join('\n')}',
                ),
              ),
            ),
            const Text(
              'Nhập lại giữ lịch sử và lịch riêng của lớp. Dữ liệu thiếu trong tệp mới không bị xóa.',
            ),
            VmFeedback(workspace),
            AppButton(
              'Xác nhận import',
              busy: workspace.busy,
              onPressed: () async {
                if (await workspace.importClasses(
                      vm.preview,
                      vm.selected!.name.split('.').last,
                    ) &&
                    context.mounted) {
                  Navigator.popUntil(context, (r) => r.isFirst);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberSelect extends StatelessWidget {
  const _NumberSelect({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
        .toList(),
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.classId});
  final String classId;
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final weeks = TextEditingController(text: '10');
  DateTime start = dateOnly(DateTime.now());
  int count = 1, day = 1, second = 3, slot = 1, secondSlot = 1, makeupSlot = 1;
  final Set<String> holidays = {};
  final List<DateTime> makeups = [];
  @override
  void dispose() {
    weeks.dispose();
    super.dispose();
  }

  Future<DateTime?> pick() => showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WorkspaceVm>(),
        c = vm.workspace!.classroom(widget.classId);
    return AppPage(
      title: 'Cấu hình lịch ${c.code}',
      child: PageList(
        children: [
          const Text(
            'Chỉ được thay lịch trước khi bất kỳ buổi nào của lớp bắt đầu. Slot là lần học; khung giờ là thời gian trong ngày.',
          ),
          AppField(
            label: 'Số tuần (1–52)',
            controller: weeks,
            keyboardType: TextInputType.number,
          ),
          AppButton(
            'Bắt đầu: ${dayKey(start)}',
            secondary: true,
            onPressed: () async {
              final date = await pick();
              if (date != null) setState(() => start = date);
            },
          ),
          _NumberSelect(
            label: 'Slot / tuần',
            value: count,
            values: const [1, 2],
            onChanged: (v) => setState(() => count = v),
          ),
          _NumberSelect(
            label: 'Ngày học 1 (1=T2, 7=CN)',
            value: day,
            values: const [1, 2, 3, 4, 5, 6, 7],
            onChanged: (v) => setState(() => day = v),
          ),
          _NumberSelect(
            label: 'Khung giờ 1',
            value: slot,
            values: const [1, 2, 3, 4],
            onChanged: (v) => setState(() => slot = v),
          ),
          if (count == 2) ...[
            _NumberSelect(
              label: 'Ngày học 2',
              value: second,
              values: const [1, 2, 3, 4, 5, 6, 7],
              onChanged: (v) => setState(() => second = v),
            ),
            _NumberSelect(
              label: 'Khung giờ 2',
              value: secondSlot,
              values: const [1, 2, 3, 4],
              onChanged: (v) => setState(() => secondSlot = v),
            ),
          ],
          AppButton(
            'Thêm ngày nghỉ',
            secondary: true,
            onPressed: () async {
              final date = await pick();
              if (date != null) setState(() => holidays.add(dayKey(date)));
            },
          ),
          ...holidays.map(
            (d) => ListTile(
              title: Text('Nghỉ: $d'),
              trailing: IconButton(
                tooltip: 'Bỏ ngày nghỉ $d',
                onPressed: () => setState(() => holidays.remove(d)),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          AppButton(
            'Thêm ngày học bù',
            secondary: true,
            onPressed: () async {
              final date = await pick();
              if (date != null) setState(() => makeups.add(date));
            },
          ),
          ...makeups.map(
            (d) => ListTile(
              title: Text('Học bù: ${dayKey(d)}'),
              trailing: IconButton(
                tooltip: 'Bỏ ngày học bù',
                onPressed: () => setState(() => makeups.remove(d)),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          _NumberSelect(
            label: 'Khung giờ học bù',
            value: makeupSlot,
            values: const [1, 2, 3, 4],
            onChanged: (v) => setState(() => makeupSlot = v),
          ),
          VmFeedback(vm),
          AppButton(
            'Lưu lịch lớp',
            busy: vm.busy,
            onPressed: () async {
              if (await vm.configure(
                    c.id,
                    start,
                    int.tryParse(weeks.text) ?? 0,
                    [
                      ScheduleRule(day, slot),
                      if (count == 2) ScheduleRule(second, secondSlot),
                    ],
                    holidays,
                    makeups,
                    makeupSlot,
                  ) &&
                  context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
