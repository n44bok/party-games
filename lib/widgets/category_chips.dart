import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../models/game_mode.dart';
import 'glass_pill.dart';

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
    return OptionPills<Category?>(
      options: [
        (null, s['all']),
        for (final c in Category.values) (c, s[c.id]),
      ],
      selected: selected,
      onSelected: onSelected,
    );
  }
}
