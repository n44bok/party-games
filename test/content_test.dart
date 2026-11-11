import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  group('sound files', () {
    /// Reads the length and format straight from the WAV header.
    ({int channels, int rate, int bits, double seconds}) wav(String name) {
      final bytes = File('assets/sounds/$name.wav').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
      expect(tag(0), 'RIFF', reason: '$name is not a RIFF file');
      expect(tag(8), 'WAVE', reason: '$name is not a WAVE file');
      expect(tag(12), 'fmt ');
      final channels = data.getUint16(22, Endian.little);
      final rate = data.getUint32(24, Endian.little);
      final bits = data.getUint16(34, Endian.little);
      expect(tag(36), 'data');
      final size = data.getUint32(40, Endian.little);
      return (
        channels: channels,
        rate: rate,
        bits: bits,
        seconds: size / (rate * channels * bits ~/ 8),
      );
    }

    test('the warning is a short signal', () {
      final w = wav('warning');
      expect(w.bits, 16);
      expect(w.seconds, inInclusiveRange(0.3, 2.0));
    });

    test('the time-up buzzer is a bit longer than the warning', () {
      final warning = wav('warning');
      final timeUp = wav('time_up');
      expect(timeUp.bits, 16);
      expect(timeUp.seconds, inInclusiveRange(0.5, 3.0));
      expect(timeUp.seconds, greaterThan(warning.seconds));
    });

    test('neither file is silent', () {
      for (final name in ['warning', 'time_up']) {
        final bytes = File('assets/sounds/$name.wav').readAsBytesSync();
        final samples = ByteData.sublistView(bytes, 44);
        var peak = 0;
        for (var i = 0; i + 1 < samples.lengthInBytes; i += 2) {
          final v = samples.getInt16(i, Endian.little).abs();
          if (v > peak) peak = v;
        }
        expect(peak, greaterThan(5000), reason: '$name is too quiet');
      }
    });
  });
}
