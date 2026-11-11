import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/game_mode.dart';

/// "All" plus one chip per [Category]; `null` means all categories.
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
    Widget chip(String label, IconData? icon, Category? value) => ChoiceChip(
      avatar: icon == null ? null : Icon(icon, size: 18),
      label: Text(label),
      selected: selected == value,
      showCheckmark: false,
      onSelected: (_) => onSelected(value),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(s['all'], null, null),
        for (final c in Category.values) chip(s[c.id], c.icon, c),
      ],
    );
  }
}
