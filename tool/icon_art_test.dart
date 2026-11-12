// Draws the app icon artwork into assets/icon/*.png. Not part of the test suite:
// run it with `flutter test tool/icon_art_test.dart`, then
// `dart run flutter_launcher_icons` to build every size from the PNGs.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

void _cups(Canvas c, {double scale = 1}) {
  c.save();
  c.translate(_size / 2, _size / 2);
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

void _background(Canvas c) {
  const rect = Rect.fromLTWH(0, 0, _size, _size);
  c.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4A2A8F), Color(0xFF1A0E3F), Color(0xFF0F0820)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect),
  );
  c.drawCircle(
    const Offset(520, 470),
    430,
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(520, 470),
        430,
        [
          const Color(0xFFB45CF5).withValues(alpha: 0.55),
          const Color(0xFFB45CF5).withValues(alpha: 0),
        ],
      ),
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

void main() {
  testWidgets('draw the icon', (tester) async {
    // iOS and legacy Android: everything in one picture, full bleed.
    await _save(tester, 'icon.png', (c) {
      _background(c);
      _cups(c, scale: 1.4);
    });
    // Android adaptive icon: the same background and the cups on their own,
    // smaller so they stay inside the safe zone of every mask.
    await _save(tester, 'icon_background.png', _background);
    await _save(tester, 'icon_foreground.png', (c) => _cups(c, scale: 0.98));
    expect(math.pi, greaterThan(3));
  });
}
