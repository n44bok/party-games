import 'package:flutter/material.dart';

import 'glass.dart';

/// One choice in a [MultiSelectField]: what it is, how it reads, and whether it
/// is separated from the ones before it (a divider above).
class MultiSelectOption<T> {
  const MultiSelectOption({
    required this.value,
    required this.id,
    required this.label,
    this.separated = false,
  });

  final T value;

  /// Stable name of the option, used for keys (`option_<id>`).
  final String id;
  final String label;
  final bool separated;
}

/// A field that shows what is chosen and opens a list with checkboxes to
/// change it. Several values can be chosen, and a "select all" row sits at the
/// top.
///
/// The caller owns the selection ([selected]) and is told about every change
/// through [onToggle] and [onSelectAll]; it decides what is allowed (for
/// instance keeping at least one chosen). Changes show in the open list
/// straight away.
class MultiSelectField<T> extends StatelessWidget {
  const MultiSelectField({
    super.key,
    required this.options,
    required this.selected,
    required this.summary,
    required this.title,
    required this.selectAllLabel,
    required this.doneLabel,
    required this.onToggle,
    required this.onSelectAll,
    required this.allSelected,
    this.fieldKey,
  });

  final List<MultiSelectOption<T>> options;
  final Set<T> selected;

  /// What the closed field says, e.g. "Places, Food +2".
  final String summary;

  /// Heading of the list.
  final String title;
  final String selectAllLabel;
  final String doneLabel;
  final ValueChanged<T> onToggle;

  /// Called when "select all" is tapped; the caller works out whether that
  /// means selecting everything or clearing back to a default.
  final VoidCallback onSelectAll;

  /// Whether every regular option is selected. Asked again each time the list
  /// redraws, so the "select all" checkbox follows the choices.
  final bool Function() allSelected;

  /// Key for the tappable field itself.
  final Key? fieldKey;

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MultiSelectSheet<T>(
        options: options,
        selected: selected,
        title: title,
        selectAllLabel: selectAllLabel,
        doneLabel: doneLabel,
        onToggle: onToggle,
        onSelectAll: onSelectAll,
        allSelected: allSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: fieldKey,
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.options,
    required this.selected,
    required this.title,
    required this.selectAllLabel,
    required this.doneLabel,
    required this.onToggle,
    required this.onSelectAll,
    required this.allSelected,
  });

  final List<MultiSelectOption<T>> options;

  /// The caller's own set: it changes under us as choices are made.
  final Set<T> selected;
  final String title;
  final String selectAllLabel;
  final String doneLabel;
  final ValueChanged<T> onToggle;
  final VoidCallback onSelectAll;
  final bool Function() allSelected;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  void _toggle(T value) {
    widget.onToggle(value);
    setState(() {}); // the caller changed the set; redraw the checkmarks
  }

  void _selectAll() {
    widget.onSelectAll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF1B1230),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        // Material so the taps' ripples paint above the dark fill.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('multiSelectDone'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(widget.doneLabel),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      _SelectRow(
                        key: const Key('multiSelectAll'),
                        label: widget.selectAllLabel,
                        checked: widget.allSelected(),
                        bold: true,
                        onTap: _selectAll,
                      ),
                      const _Divider(),
                      for (final option in widget.options) ...[
                        if (option.separated) const _Divider(),
                        _SelectRow(
                          key: ValueKey('option_${option.id}'),
                          label: option.label,
                          checked: widget.selected.contains(option.value),
                          onTap: () => _toggle(option.value),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 20,
    endIndent: 20,
    color: Colors.white.withValues(alpha: 0.10),
  );
}

/// One row: a round checkbox and a label; the whole row is tappable.
class _SelectRow extends StatelessWidget {
  const _SelectRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onTap,
    this.bold = false,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: checked ? brandGradient : null,
                  border: checked
                      ? null
                      : Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.6,
                        ),
                ),
                child: checked
                    ? const Icon(
                        Icons.check_rounded,
                        key: Key('checkMark'),
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
