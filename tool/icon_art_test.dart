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

void _cup(
  Canvas c, {
  required Offset at,
  required double scale,
  required double angle,
  required List<Color> body,
  required Color rim,
  required Color inside,
  double shine = 0.22,
}) {
  const h = 400.0, wt = 300.0, wb = 206.0;
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(angle);
  c.scale(scale);

  // Soft shadow under the cup.
  c.drawOval(
    Rect.fromCenter(center: const Offset(0, h / 2 + 8), width: 300, height: 56),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
  );

  final bodyPath = Path()
    ..moveTo(-wt / 2, -h / 2)
    ..lineTo(wt / 2, -h / 2)
    ..lineTo(wb / 2, h / 2 - 26)
    ..quadraticBezierTo(wb / 2 - 4, h / 2, wb / 2 - 30, h / 2)
    ..lineTo(-wb / 2 + 30, h / 2)
    ..quadraticBezierTo(-wb / 2 + 4, h / 2, -wb / 2, h / 2 - 26)
    ..close();
  c.drawPath(
    bodyPath,
    Paint()
      ..shader = LinearGradient(
        colors: body,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(-wt / 2, -h / 2, wt, h)),
  );
  // Light from the left, shade on the right.
  c.drawPath(
    bodyPath,
    Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: shine),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.28),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(const Rect.fromLTWH(-wt / 2, -h / 2, wt, h)),
  );
  // The two ridges of a party cup.
  for (final y in [h / 2 - 118.0, h / 2 - 84.0]) {
    final inset = (wt - wb) / 2 * ((y + h / 2) / h);
    final half = wt / 2 - inset;
    c.drawLine(
      Offset(-half, y),
      Offset(half, y),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..strokeWidth = 5,
    );
    c.drawLine(
      Offset(-half, y + 5),
      Offset(half, y + 5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 3,
    );
  }

  // Rim and the inside of the cup.
  final rimRect = Rect.fromCenter(
    center: const Offset(0, -h / 2),
    width: wt + 14,
    height: 78,
  );
  c.drawOval(rimRect, Paint()..color = rim);
  c.drawOval(
    Rect.fromCenter(
      center: const Offset(0, -h / 2 + 4),
      width: wt - 26,
      height: 56,
    ),
    Paint()
      ..shader = LinearGradient(
        colors: [inside, Color.lerp(inside, Colors.black, 0.35)!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rimRect),
  );
  c.restore();
}

void _cups(Canvas c, {double scale = 1, Offset at = const Offset(512, 512)}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale);
  c.translate(-_size / 2 - 8, -_size / 2 - 18);
  _cup(
    c,
    at: const Offset(392, 500),
    scale: 0.82,
    angle: -0.2,
    body: const [Color(0xFFD83A86), Color(0xFF7A1048)],
    rim: const Color(0xFFD9C2F5),
    inside: const Color(0xFF9A6FD8),
    shine: 0.14,
  );
  _cup(
    c,
    at: const Offset(618, 548),
    scale: 1.0,
    angle: 0.17,
    body: const [Color(0xFFFF5C98), Color(0xFFB01258)],
    rim: const Color(0xFFF1E3FF),
    inside: const Color(0xFFC6A2F5),
  );
  c.restore();
}

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

/// The same backdrop as the app's home screen (GradientBackground): deep
/// purple at the top, lighter purple at the bottom.
void _background(Canvas c) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  c.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF140B2B), Color(0xFF26144A), Color(0xFF5A3A98)],
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

/// The cups of the home screen header (assets/images/party_cups.jpg), faded
/// into the background with the same radial mask the app uses.
void _cupsPhoto(Canvas c, ui.Image photo, {required Offset at}) {
  final dest = Rect.fromLTWH(at.dx, at.dy, 900, 600);
  c.saveLayer(dest, Paint());
  c.drawImageRect(
    photo,
    Rect.fromLTWH(0, 0, photo.width.toDouble(), photo.height.toDouble()),
    dest,
    Paint()..filterQuality = FilterQuality.high,
  );
  // Fade the photo out in an ellipse around the cups, so only they and a soft
  // shadow remain on the background.
  c.drawRect(
    dest,
    Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = const RadialGradient(
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.74, 1.0],
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
      ..translate(center.dx, center.dy)
      ..scale(stretch, 1.0)
      ..translate(-center.dx, -center.dy);
  }
}

/// The whole picture: the name at the top and the cups below it, the way the
/// app's home screen is laid out.
void _artwork(Canvas c, ui.Image photo, {required double scale}) {
  c.save();
  c.translate(_size / 2, _size / 2);
  c.scale(scale);
  c.translate(-_size / 2, -_size / 2);
  _wordmark(c, at: const Offset(96, 80), width: 800);
  _cupsPhoto(c, photo, at: const Offset(70, 470));
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
