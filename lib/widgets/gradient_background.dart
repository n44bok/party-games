import 'package:flutter/material.dart';

/// Deep purple backdrop shared by all screens.
///
/// With [dark] it is nearly black with a pink haze in the bottom-right corner,
/// used by the game screen.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child, this.dark = false});

  final Widget child;
  final bool dark;

  /// On tablets (and phones in landscape) the content stays a phone-sized
  /// column in the middle; the backdrop still fills the whole screen.
  static const maxContentWidth = 600.0;

  @override
  Widget build(BuildContext context) {
    final colors = dark
        ? const [Color(0xFF110C1E), Color(0xFF191030), Color(0xFF241437)]
        : const [Color(0xFF140B2B), Color(0xFF26144A), Color(0xFF5A3A98)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (dark)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.0, 1.0),
                  radius: 1.1,
                  colors: [
                    const Color(0xFFF06FB5).withValues(alpha: 0.20),
                    const Color(0xFFF06FB5).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final side = ((constraints.maxWidth - maxContentWidth) / 2)
                  .clamp(0.0, double.infinity);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: side),
                child: child,
              );
            },
          ),
        ],
      ),
    );
  }
}
