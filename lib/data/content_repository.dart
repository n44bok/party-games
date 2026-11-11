import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/game_mode.dart';

/// Loads prompts from `assets/content/{lang}/{file}.json`.
class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<List<Prompt>> load(GameMode mode, String lang, Strings0 labels) async {
    final result = <Prompt>[];
    for (final file in mode.files) {
      final raw = await _bundle.loadString('assets/content/$lang/$file.json');
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        if (item is List) {
          result.add(Prompt(item[0] as String, optionB: item[1] as String));
        } else {
          result.add(Prompt(item as String,
              label: mode == GameMode.truthOrDare ? labels(file) : null));
        }
      }
    }
    return result;
  }
}

/// Resolves a content file name ("truth"/"dare") to a localized badge.
typedef Strings0 = String Function(String key);
