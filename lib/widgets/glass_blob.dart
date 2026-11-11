import 'package:flutter/material.dart';

/// An organic, slightly lopsided glass "blob" with a soft glow, used as the
/// backdrop of a large icon on the mode and Premium screens.
class GlassBlob extends StatelessWidget {
  const GlassBlob({
    super.key,
    required this.child,
    this.width = 168,
    this.height = 154,
    this.fill = const [Color(0xFFB07CFF), Color(0xFF5B3A98)],
    this.glow = const Color(0xFF8A5CFF),
  });

  final Widget child;
  final double width;
  final double height;

  /// Top-left and bottom-right colors of the glass fill.
  final List<Color> fill;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    // Corner radii scale with the size so any blob keeps the same shape.
    final w = width / 168;
    final h = height / 154;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.elliptical(92 * w, 80 * h),
          topRight: Radius.elliptical(64 * w, 92 * h),
          bottomRight: Radius.elliptical(88 * w, 68 * h),
          bottomLeft: Radius.elliptical(68 * w, 88 * h),
        ),
        gradient: LinearGradient(
          colors: [
            fill.first.withValues(alpha: 0.7),
            fill.last.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: glow.withValues(alpha: 0.45), blurRadius: 32),
        ],
      ),
      child: child,
    );
  }
}
