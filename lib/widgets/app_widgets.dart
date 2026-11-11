import 'package:flutter/material.dart';

import '../models/workspace.dart';
import '../theme/app_theme.dart';
import '../viewmodels/base_vm.dart';

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.busy = false,
    this.secondary = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy, secondary;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox.square(
            dimension: AppSpace.xl,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon),
        if (busy || icon != null) const SizedBox(width: AppSpace.sm),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return Semantics(
      button: true,
      label: label,
      child: secondary
          ? OutlinedButton(onPressed: busy ? null : onPressed, child: child)
          : FilledButton(onPressed: busy ? null : onPressed, child: child),
    );
  }
}

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.suffix,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final String? error, hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    enabled: enabled,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      suffixIcon: suffix,
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Padding(padding: const EdgeInsets.all(AppSpace.lg), child: child),
    ),
  );
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottom,
    this.constrain = true,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool constrain;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    bottomNavigationBar: bottom,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constrain ? AppSpace.formWidth : double.infinity,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class PageList extends StatelessWidget {
  const PageList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpace.lg),
    children: [
      for (var i = 0; i < children.length; i++) ...[
        children[i],
        if (i < children.length - 1) const SizedBox(height: AppSpace.lg),
      ],
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

class VmFeedback extends StatelessWidget {
  const VmFeedback(this.vm, {super.key, this.retry});
  final BaseVm vm;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) {
    final text = vm.error ?? vm.message;
    if (text == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  vm.error == null ? Icons.info_outline : Icons.error_outline,
                  color: vm.error == null ? AppColors.info : AppColors.error,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Text(text)),
              ],
            ),
            if (vm.error != null && retry != null)
              TextButton(
                onPressed: vm.busy ? null : retry,
                child: const Text('Thử lại'),
              ),
          ],
        ),
      ),
    );
  }
}

class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.state,
    this.message = 'Chưa có dữ liệu.',
    this.onRetry,
    this.actionLabel = 'Thử lại',
  });
  final LoadState state;
  final String message, actionLabel;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == LoadState.loading)
            const CircularProgressIndicator()
          else
            Icon(
              state == LoadState.error
                  ? Icons.cloud_off_outlined
                  : Icons.inbox_outlined,
              size: AppSpace.touch,
            ),
          const SizedBox(height: AppSpace.lg),
          Text(
            state == LoadState.loading ? 'Đang tải dữ liệu…' : message,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.lg),
            AppButton(actionLabel, onPressed: onRetry),
          ],
        ],
      ),
    ),
  );
}

class AppNavigation extends StatelessWidget {
  const AppNavigation({super.key, required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index,
    onDestinationSelected: onSelect,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: 'Lịch tuần & lớp',
      ),
      NavigationDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud),
        label: 'Drive',
      ),
    ],
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String body, {
  String confirm = 'Xác nhận',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;

String meetingLabel(Meeting m) => switch (m.state) {
  MeetingState.upcoming => 'Chưa bắt đầu',
  MeetingState.active => 'Đang điểm danh',
  MeetingState.closed => 'Đã chốt',
};
String markLabel(Mark? mark) => switch (mark) {
  Mark.present => 'Present (P) · Có mặt',
  Mark.absent => 'Absent (A) · Vắng',
  null => 'Chưa ghi nhận',
};

class AttendanceStatus extends StatelessWidget {
  const AttendanceStatus(this.mark, {super.key});
  final Mark? mark;
  @override
  Widget build(BuildContext context) => Text(
    markLabel(mark),
    style: TextStyle(
      color: mark == Mark.present
          ? AppColors.success
          : mark == Mark.absent
          ? AppColors.error
          : AppColors.secondary,
    ),
  );
}

class MeetingCell extends StatelessWidget {
  const MeetingCell({
    super.key,
    required this.classroom,
    required this.meeting,
    required this.onTap,
  });
  final ClassRoom classroom;
  final Meeting meeting;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${classroom.subject} ${classroom.code} Slot ${meeting.number} ${dayKey(meeting.date)} ${timeSlots[meeting.timeSlot - 1]} ${meetingLabel(meeting)}',
    button: true,
    child: AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            classroom.subject,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(classroom.code),
          Text('Slot ${meeting.number} · ${classroom.students.length} SV'),
          Text(
            timeSlots[meeting.timeSlot - 1],
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            meetingLabel(meeting),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class StudentRow extends StatelessWidget {
  const StudentRow({
    super.key,
    required this.student,
    required this.record,
    required this.manual,
    required this.enabled,
    required this.onDetails,
    required this.onMark,
  });
  final Student student;
  final AttendanceRecord? record;
  final bool manual, enabled;
  final VoidCallback onDetails;
  final ValueChanged<Mark> onMark;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Chi tiết sinh viên ${student.id}',
          button: true,
          child: InkWell(
            onTap: onDetails,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpace.touch),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(student.id),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        AttendanceStatus(record?.mark),
        if (record?.audit.isNotEmpty ?? false)
          const Text('Có ghi chú chỉnh sửa'),
        if (manual) ...[
          const SizedBox(height: AppSpace.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<Mark>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: Mark.present, label: Text('P · Có mặt')),
                ButtonSegment(value: Mark.absent, label: Text('A · Vắng')),
              ],
              selected: record == null ? {} : {record!.mark},
              onSelectionChanged: !enabled
                  ? null
                  : (values) {
                      if (values.isNotEmpty) onMark(values.first);
                    },
            ),
          ),
        ],
      ],
    ),
  );
}
