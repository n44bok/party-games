import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/game_mode.dart';
import 'glass.dart';

/// "All" plus one pill per [Category]; `null` means all categories.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Category? selected;
  final ValueChanged<Category?> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    Widget pill(String label, Category? value) => _Pill(
      label: label,
      selected: selected == value,
      onTap: () => onSelected(value),
    );
    final items = <Widget>[
      pill(s['all'], null),
      for (final c in Category.values) pill(s[c.id], c),
    ];
    // One evenly spread row, like the design.
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: items[i]),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
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
                      color: brandGradient.colors.first.withValues(alpha: 0.45),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
