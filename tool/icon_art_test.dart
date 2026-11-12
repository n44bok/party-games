// Draws the app icon artwork into assets/icon/*.png. Not part of the test suite:
// run it with `flutter test tool/icon_art_test.dart`, then
// `dart run flutter_launcher_icons` to build every size from the PNGs.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;

/// "Party" in white and "Games" in the brand gradient, like the app's header.
/// Returns the height used, so the cups can sit below it.
double _wordmark(Canvas c, {required Offset at, required double width}) {
  TextPainter line(String text, Paint? foreground) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'RobotoBlack',
        fontSize: 300,
        height: 0.98,
        letterSpacing: -6,
        color: foreground == null ? Colors.white : null,
        foreground: foreground,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final probe = line('Games', null);
  final k = width / probe.width;
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(k);
  line('Party', null).paint(c, Offset.zero);
  final gradient = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFFA66BFF), Color(0xFFF06FB5)],
    ).createShader(Rect.fromLTWH(0, 0, probe.width, probe.height));
  line('Games', gradient).paint(c, Offset(0, probe.height * 0.86));
  c.restore();
  return probe.height * 1.86 * k;
}

/// The backdrop of the app's home screen (GradientBackground): deep purple at
/// the top, lighter purple at the bottom. It stays dark for a little longer
/// than in the app, so the photo of the cups blends in without any edge.
void _background(Canvas c) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  c.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF140B2B),
          Color(0xFF1C0E3A),
          Color(0xFF2E1A5C),
          Color(0xFF5A3A98),
        ],
        stops: [0.0, 0.34, 0.68, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect),
  );
}

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

/// The cups of the home screen header (assets/images/party_cups.jpg), exactly
/// as the app shows them: the photo as it is, faded out towards its edges.
///
/// The photo's own background is very dark purple, the same as the top of the
/// app's gradient, so it only blends in where the icon's background is that
/// dark too. That is why the cups sit in the top part of the icon.
void _cupsPhoto(Canvas c, ui.Image photo, {required Offset at}) {
  final dest = Rect.fromLTWH(at.dx, at.dy, 900, 600);
  c.saveLayer(dest, Paint());
  c.drawImageRect(
    photo,
    Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
    dest,
    Paint()..filterQuality = FilterQuality.high,
  );
  c.drawRect(
    dest,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = const RadialGradient(
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.6, 1.0],
        transform: _Ellipse(1.5),
      ).createShader(dest),
  );
  c.restore();
}

/// Stretches a radial gradient sideways into an ellipse.
class _Ellipse extends GradientTransform {
  const _Ellipse(this.stretch);

  final double stretch;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final center = bounds.center;
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(stretch, 1, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
  }
}

/// The whole picture: the cups at the top, on the dark part of the background
/// where the photo blends in as it does in the app, and the name below.
void _artwork(Canvas c, ui.Image photo, {required double scale}) {
  c.save();
  c.translate(_size / 2, _size / 2);
  c.scale(scale);
  c.translate(-_size / 2, -_size / 2);
  _cupsPhoto(c, photo, at: const Offset(60, -30));
  _wordmark(c, at: const Offset(110, 560), width: 760);
  c.restore();
}

void main() {
  testWidgets('draw the icon', (tester) async {
    await tester.runAsync(() async {
      final root = Platform.environment['FLUTTER_ROOT']!;
      final bytes = File(
        '$root/bin/cache/artifacts/material_fonts/Roboto-Black.ttf',
      ).readAsBytesSync();
      final loader = FontLoader('RobotoBlack')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    });
    final photo = (await tester.runAsync(() async {
      final bytes = File('assets/images/party_cups.jpg').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    }))!;
    // iOS and legacy Android: everything in one picture, full bleed.
    await _save(tester, 'icon.png', (c) {
      _background(c);
      _artwork(c, photo, scale: 1.0);
    });
    // Android adaptive icon: the same background and the artwork on its own,
    // smaller so it stays inside the safe zone of every mask.
    await _save(tester, 'icon_background.png', _background);
    await _save(
      tester,
      'icon_foreground.png',
      (c) => _artwork(c, photo, scale: 0.68),
    );
    expect(math.pi, greaterThan(3));
  });
}
