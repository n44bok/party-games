import 'package:flutter/material.dart';

/// Brand gradient (purple to pink) used for text accents and selected pills.
const brandGradient = LinearGradient(
  colors: [Color(0xFFB45CF5), Color(0xFFF472B6)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

/// Primary button fill: violet, magenta, then coral in the bottom-right.
const primaryGradient = LinearGradient(
  colors: [Color(0xFF7B5CF6), Color(0xFFC96CE0), Color(0xFFF4797F)],
  stops: [0.0, 0.6, 1.0],
  begin: Alignment(-1, -0.4),
  end: Alignment(1, 0.7),
);

/// Hairline border: bright at the top-left, fading, with a pink return.
const _defaultBorder = LinearGradient(
  colors: [Color(0x61FFFFFF), Color(0x12FFFFFF), Color(0x33FFFFFF)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Translucent panel with a gradient hairline border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.gradient,
    this.borderGradient = _defaultBorder,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Overrides the default dark glass fill.
  final Gradient? gradient;

  /// Colors of the 1px border.
  final Gradient borderGradient;

  static const borderWidth = 1.2;
  static final _glassBase = const Color(0xFF140B2B).withValues(alpha: 0.6);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: borderGradient,
      ),
      child: Padding(
        padding: const EdgeInsets.all(borderWidth),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius - borderWidth),
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

/// Full-width pill button: diagonal violet-to-coral fill, glossy top edge and
/// a bright gradient border, with a soft glow around it.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.height = 56,
    this.gradient = primaryGradient,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final double height;
  final Gradient gradient;

  static const _border = 1.4;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    // The glow sits on the outermost box: Ink/clips would cut a shadow into a
    // hard strip.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          colors: [Color(0xB3FFFFFF), Color(0x66F4A0D0), Color(0x40FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC96CE0).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_border),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - _border),
          child: SizedBox(
            height: height - 2 * _border,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
                // Glossy highlight on the top half.
                Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.5,
                    widthFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
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
    this.height = 56,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: height / 2,
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onPressed,
          child: SizedBox(
            height: height - 2 * GlassCard.borderWidth,
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
      ),
    );
  }
}
