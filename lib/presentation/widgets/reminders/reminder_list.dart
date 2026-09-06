import 'package:flutter/material.dart';

import '../../../core/theme/tokens_context.dart';
import '../../../l10n/l10n_extensions.dart';
import '../common/grouped_list.dart';

class ReminderList extends StatelessWidget {
  final List<Widget> children;
  final Widget header;
  final Widget footer;
  final bool isReordering;
  final ReorderCallback? onReorder;

  const ReminderList({
    super.key,
    required this.children,
    required this.header,
    required this.footer,
    this.isReordering = false,
    this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (!isReordering || onReorder == null) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header,
          GroupedList(children: children),
          footer,
        ],
      );
    }
    final tokens = context.tokens;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      onReorderItem: onReorder,
      padding: const EdgeInsets.only(bottom: 24),
      header: header,
      footer: footer,
      itemCount: children.length,
      itemBuilder: (context, index) => Container(
        key: children[index].key,
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border(bottom: BorderSide(color: tokens.divider)),
        ),
        child: Row(
          children: [
            Expanded(child: children[index]),
            ReorderableDragStartListener(
              key: ValueKey('reminder-drag-$index'),
              index: index,
              child: Tooltip(
                message: context.l10n.reminderReorder,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
