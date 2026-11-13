import 'dart:math' as math;

import 'package:flutter/material.dart';

/// On tablets the whole interface is drawn larger, as if the tablet were a
/// big phone, instead of leaving small controls in a sea of space.
///
/// The child is laid out at a smaller "virtual" size and then scaled up to
/// fill the screen, so every screen, dialog and the system insets stay
/// consistent. Phones (and anything smaller than the reference size) are
/// left untouched.
class TabletScale extends StatelessWidget {
  const TabletScale({super.key, required this.child});

  final Widget child;

  /// A phone-sized layout the app is designed around.
  static const referenceWidth = 420.0;
  static const referenceHeight = 700.0;
  static const maxScale = 1.4;

  /// The scale for a screen of [size] (logical pixels); 1 means no scaling.
  static double scaleFor(Size size) => math
      .min(size.width / referenceWidth, size.height / referenceHeight)
      .clamp(1.0, maxScale);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = scaleFor(media.size);
    if (scale <= 1.001) return child;

    final inner = Size(media.size.width / scale, media.size.height / scale);
    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: inner.width,
        maxWidth: inner.width,
        minHeight: inner.height,
        maxHeight: inner.height,
        child: MediaQuery(
          data: media.copyWith(
            size: inner,
            padding: media.padding / scale,
            viewPadding: media.viewPadding / scale,
            viewInsets: media.viewInsets / scale,
            systemGestureInsets: media.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
