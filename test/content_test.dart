import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_games/data/strings.dart';
import 'package:party_games/models/game_mode.dart';

void main() {
  const files = [
    'would_you_rather',
    'most_likely',
    'never_have_i_ever',
    'this_or_that',
    'truth',
    'dare',
  ];

  Map<String, dynamic> read(String lang, String file) =>
      jsonDecode(File('assets/content/$lang/$file.json').readAsStringSync())
          as Map<String, dynamic>;

  for (final file in files) {
    test('$file: valid categories, unique, same shape in every language', () {
      final shapes = <String>{};
      for (final lang in Strings.supported) {
        final data = read(lang, file);
        expect(
          data.keys.toSet(),
          Category.values.map((c) => c.id).toSet(),
          reason: 'categories of $lang/$file',
        );
        final all = <String>[];
        for (final entry in data.entries) {
          expect(entry.value, isNotEmpty, reason: '${entry.key} is empty');
          for (final item in entry.value as List) {
            if (file == 'would_you_rather' || file == 'this_or_that') {
              expect(item, isA<List>());
              expect((item as List).length, 2);
            } else {
              expect(item, isA<String>());
            }
            all.add(item.toString());
          }
        }
        expect(
          all.toSet().length,
          all.length,
          reason: 'duplicates in $lang/$file',
        );
        shapes.add(
          data.entries
              .map((e) => '${e.key}:${(e.value as List).length}')
              .join(','),
        );
      }
      expect(shapes.length, 1, reason: 'languages out of sync for $file');
    });
  }
}
