// Builds the app icon artwork in assets/icon/ from the logo
// (assets/icon/logo_source.png). Not part of the test suite: run it with
// `flutter test tool/icon_art_test.dart`, then `dart run flutter_launcher_icons`
// to build every size from the PNGs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

Future<void> _save(
  WidgetTester tester,
  String name,
  void Function(Canvas) draw,
) async {
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final image = await recorder.endRecording().toImage(
      _size.toInt(),
      _size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('assets/icon/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Draws [logo] into the square [dest].
void _logo(Canvas c, ui.Image logo, Rect dest, {Paint? paint}) {
  c.drawImageRect(
    logo,
    Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    dest,
    (paint ?? Paint())..filterQuality = FilterQuality.high,
  );
}

void main() {
  testWidgets('build the icon from the logo', (tester) async {
    final logo = (await tester.runAsync(() async {
      final bytes = File('assets/icon/logo_source.png').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    }))!;
    const full = Rect.fromLTWH(0, 0, _size, _size);

    // iOS and old Android: the logo itself, full bleed.
    await _save(tester, 'icon.png', (c) => _logo(c, logo, full));

    // Android adaptive icon. The launcher cuts a circle or a rounded square
    // out of the middle, so the logo goes in smaller (its text and cards then
    // stay inside every mask) and the margin around it is a plain wash in the
    // logo's own colours: blue at the top left, purple, pink at the right and
    // orange in the bottom right corner (colours taken from the logo's edges).
    await _save(tester, 'icon_background.png', (c) {
      Color rgb(int r, int g, int b) => Color.fromARGB(255, r, g, b);
      c.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(
            colors: [rgb(43, 28, 228), rgb(56, 3, 158), rgb(115, 4, 177)],
          ).createShader(full),
      );
      c.saveLayer(full, Paint());
      c.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(
            colors: [rgb(170, 49, 251), rgb(206, 6, 186), rgb(252, 120, 60)],
          ).createShader(full),
      );
      c.drawRect(
        full,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const LinearGradient(
            colors: [Colors.transparent, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(full),
      );
      c.restore();
      c.drawRect(
        full,
        Paint()
          ..shader = ui.Gradient.radial(
            const Offset(_size, _size * 0.62),
            _size * 0.55,
            [
              rgb(255, 10, 140).withValues(alpha: 0.7),
              rgb(255, 10, 140).withValues(alpha: 0),
            ],
          ),
      );
    });
    await _save(
      tester,
      'icon_foreground.png',
      (c) => _logo(
        c,
        logo,
        Rect.fromCenter(
          center: const Offset(_size / 2, _size / 2),
          width: _size * 0.74,
          height: _size * 0.74,
        ),
      ),
    );
  });
}
