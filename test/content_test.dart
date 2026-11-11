import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:party_games/data/strings.dart';

void main() {
  const files = ['would_you_rather', 'most_likely', 'truth', 'dare'];

  List<dynamic> read(String lang, String file) => jsonDecode(
      File('assets/content/$lang/$file.json').readAsStringSync()) as List;

  for (final file in files) {
    test('$file: valid, unique, same size in every language', () {
      final sizes = <int>{};
      for (final lang in Strings.supported) {
        final items = read(lang, file);
        expect(items, isNotEmpty);
        expect(items.map((e) => e.toString()).toSet().length, items.length,
            reason: 'duplicates in $lang/$file');
        for (final item in items) {
          if (file == 'would_you_rather') {
            expect(item, isA<List>());
            expect((item as List).length, 2);
          } else {
            expect(item, isA<String>());
          }
        }
        sizes.add(items.length);
      }
      expect(sizes.length, 1, reason: 'languages out of sync for $file');
    });
  }
}
