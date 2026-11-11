import 'package:flutter/material.dart';

/// Brand gradient (purple to pink) used for primary actions and accents.
const brandGradient = LinearGradient(
  colors: [Color(0xFFB45CF5), Color(0xFFF472B6)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

/// Translucent panel with a gradient hairline border (bright in the corners).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Overrides the default faint white fill.
  final Gradient? gradient;

  static const _border = 1.2;
  static final _glassBase = const Color(0xFF140B2B).withValues(alpha: 0.6);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.38),
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_border),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius - _border),
            gradient:
                gradient ??
                LinearGradient(
                  // Dark tinted glass with a faint light sheen.
                  colors: [
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.05),
                      _glassBase,
                    ),
                    Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.01),
                      _glassBase,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Round translucent icon button (stepper -/+).
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: enabled ? 0.10 : 0.04),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 0.22 : 0.08),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: enabled ? 1 : 0.35),
          ),
        ),
      ),
    );
  }
}

/// Full-width pill button with the brand gradient.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.height = 56,
    this.gradient = brandGradient,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final double height;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    // The glow sits outside Ink: Ink clips its decoration to its own bounds,
    // which would cut the shadow into a hard strip. Material is needed so Ink
    // paints above the screen's background.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB45CF5).withValues(alpha: 0.4),
            blurRadius: 18,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(28),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailingIcon, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width translucent pill button for secondary actions.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
