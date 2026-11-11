import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass.dart';

/// Shows a small bubble with [title] and [body] next to [anchor] (the global
/// rectangle of the widget that opened it), with an arrow pointing at it.
///
/// Opens below the anchor, or above it when the anchor is in the lower part of
/// the screen. Dismissed by tapping anywhere outside.
Future<void> showRulesPopover(
  BuildContext context, {
  required Rect anchor,
  required String title,
  required String body,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, _, _) =>
        _RulesPopover(anchor: anchor, title: title, body: body),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          // Grow out of the anchor's side of the screen.
          alignment: Alignment(
            (anchor.center.dx / MediaQuery.sizeOf(context).width) * 2 - 1,
            (anchor.center.dy / MediaQuery.sizeOf(context).height) * 2 - 1,
          ),
          scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _RulesPopover extends StatelessWidget {
  const _RulesPopover({
    required this.anchor,
    required this.title,
    required this.body,
  });

  final Rect anchor;
  final String title;
  final String body;

  static const _margin = 16.0;
  static const _gap = 10.0;
  static const _arrow = 14.0;
  static const _fill = Color(0xFF2A1B4A);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width - 2 * _margin, 300.0);
    final left = (anchor.center.dx - width / 2).clamp(
      _margin,
      size.width - _margin - width,
    );
    final opensAbove = anchor.center.dy > size.height * 0.6;
    final arrowLeft = (anchor.center.dx - _arrow / 2).clamp(
      left + 20,
      left + width - 20 - _arrow,
    );

    final bubble = GlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      gradient: LinearGradient(
        colors: [
          _fill.withValues(alpha: 0.98),
          const Color(0xFF1B1230).withValues(alpha: 0.98),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );

    final arrow = Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: _arrow,
        height: _arrow,
        decoration: BoxDecoration(
          color: _fill,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );

    // Material provides default text styles inside the dialog route.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            left: left,
            width: width,
            top: opensAbove ? null : anchor.bottom + _gap,
            bottom: opensAbove ? size.height - anchor.top + _gap : null,
            child: bubble,
          ),
          Positioned(
            left: arrowLeft,
            top: opensAbove ? null : anchor.bottom + _gap - _arrow / 2,
            bottom: opensAbove
                ? size.height - anchor.top + _gap - _arrow / 2
                : null,
            child: arrow,
          ),
        ],
      ),
    );
  }
}
