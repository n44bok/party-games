import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_games/data/strings.dart';
import 'package:party_games/models/game_mode.dart';
import 'package:party_games/spy/spy_round.dart';

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

  test('spy words: every category present, unique and in sync', () {
    final shapes = <String>{};
    for (final lang in Strings.supported) {
      final byCategory = jsonDecode(
        File('assets/content/$lang/spy_words.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(
        byCategory.keys.toSet(),
        SpyCategory.builtIn.map((c) => c.id).toSet(),
        reason: 'categories of $lang',
      );
      for (final entry in byCategory.entries) {
        final words = (entry.value as List).cast<String>();
        expect(words.length, greaterThanOrEqualTo(20), reason: entry.key);
        expect(
          words.toSet().length,
          words.length,
          reason: 'duplicates in $lang/${entry.key}',
        );
        expect(words.every((w) => w.trim().isNotEmpty), isTrue);
      }
      shapes.add(
        byCategory.entries
            .map((e) => '${e.key}:${(e.value as List).length}')
            .join(','),
      );
    }
    expect(shapes.length, 1, reason: 'languages out of sync for spy words');
  });
}
