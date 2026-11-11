import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/game_mode.dart';

/// Loads prompts from `assets/content/{lang}/{file}.json`.
///
/// Each file maps a category id to a list of prompts.
class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<Prompt>> load(GameMode mode, String lang) async {
    final result = <Prompt>[];
    for (final file in mode.files) {
      final raw = await _bundle.loadString('assets/content/$lang/$file.json');
      final byCategory = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in byCategory.entries) {
        final category = Category.fromId(entry.key);
        for (final item in entry.value as List<dynamic>) {
          if (item is List) {
            result.add(
              Prompt(item[0] as String, category, optionB: item[1] as String),
            );
          } else {
            result.add(
              Prompt(
                item as String,
                category,
                kind: mode == GameMode.truthOrDare ? file : null,
              ),
            );
          }
        }
      }
    }
    return result;
  }
}
