import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Each row shares one height across its fixed label and scrollable day cells.
/// Horizontal offsets are synchronized; all vertical movement belongs to the page.
class FrozenWeekTable extends StatefulWidget {
  const FrozenWeekTable({super.key, required this.labels, required this.rows});
  final List<Widget> labels;
  final List<List<Widget>> rows;
  @override
  State<FrozenWeekTable> createState() => _FrozenWeekTableState();
}

class _FrozenWeekTableState extends State<FrozenWeekTable> {
  late final List<ScrollController> controllers;
  bool syncing = false;
  @override
  void initState() {
    super.initState();
    controllers = List.generate(widget.rows.length, (_) => ScrollController());
    for (final source in controllers) {
      source.addListener(() {
        if (syncing || !source.hasClients) return;
        syncing = true;
        for (final target in controllers) {
          if (target != source && target.hasClients)
            target.jumpTo(
              source.offset.clamp(0, target.position.maxScrollExtent),
            );
        }
        syncing = false;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < widget.rows.length; row++)
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: ValueKey('frozen-slot-$row'),
                  width: AppSpace.slotWidth,
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: widget.labels[row],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey('week-row-$row'),
                    controller: controllers[row],
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final cell in widget.rows[row])
                          SizedBox(
                            width: AppSpace.dayWidth,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpace.xs),
                              child: cell,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
