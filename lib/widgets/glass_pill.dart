import 'package:flutter/material.dart';

import 'glass.dart';

/// A selectable pill: the chosen one glows in the brand gradient, the others
/// are glass. A disabled pill is dimmed and ignores taps.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.expand = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  /// Fill the width it is given (for rows of evenly spread pills) rather than
  /// being as wide as its label (for pills that wrap onto several lines).
  final bool expand;

  Widget get _label => Text(
    label,
    style: TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: expand ? 6 : 18),
            alignment: expand ? Alignment.center : null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFFC15BF0), Color(0xFFF06FB5)],
                    )
                  : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.35 : 0.16),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: brandGradient.colors.first.withValues(
                          alpha: 0.45,
                        ),
                        blurRadius: 14,
                      ),
                    ]
                  : null,
            ),
            child: expand
                ? FittedBox(fit: BoxFit.scaleDown, child: _label)
                : Center(widthFactor: 1, child: _label),
          ),
        ),
      ),
    );
  }
}

/// One row of evenly spread [GlassPill]s for choosing a single value.
class OptionPills<T> extends StatelessWidget {
  const OptionPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.isEnabled,
  });

  /// (value, label) pairs, in display order.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Options for which this returns false are dimmed and cannot be chosen.
  final bool Function(T value)? isEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GlassPill(
              label: options[i].$2,
              selected: options[i].$1 == selected,
              enabled: isEnabled?.call(options[i].$1) ?? true,
              onTap: () => onSelected(options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

/// [GlassPill]s for choosing one value, wrapping onto as many lines as needed.
/// Use this instead of [OptionPills] when there are too many options for a row.
class PillWrap<T> extends StatelessWidget {
  const PillWrap({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  /// (value, label) pairs, in display order.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          GlassPill(
            label: label,
            selected: value == selected,
            expand: false,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

/// [GlassPill]s for choosing any number of values, wrapping onto as many lines
/// as needed. Tapping a pill reports it through [onToggle]; the caller decides
/// what that does (for instance refusing to clear the last one).
class MultiPillWrap<T> extends StatelessWidget {
  const MultiPillWrap({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  /// (value, label) pairs, in display order.
  final List<(T, String)> options;
  final Set<T> selected;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          GlassPill(
            label: label,
            selected: selected.contains(value),
            expand: false,
            onTap: () => onToggle(value),
          ),
      ],
    );
  }
}
