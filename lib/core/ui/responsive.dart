import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Width breakpoints (logical pixels), following Material 3 window classes.
class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
}

/// Width for dialog content: [max] on large screens, shrinking on phones.
double dialogWidth(BuildContext context, {double max = 500}) {
  final screen = MediaQuery.sizeOf(context).width;
  // 80 = dialog inset padding (2 x 40) + content padding.
  return math.max(240, math.min(max, screen - 112));
}

/// Height for dialog content that needs a fixed height (e.g. lists).
/// Shrinks on short screens, landscape phones and with the keyboard open.
double dialogHeight(BuildContext context, {double max = 450}) {
  final media = MediaQuery.of(context);
  final available = media.size.height - media.viewInsets.bottom;
  // Leaves room for the title, action buttons and dialog padding.
  return math.max(160, math.min(max, available - 220));
}

/// Centers [child] and limits its width so content doesn't stretch across
/// tablets and desktop windows.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentWidth({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
