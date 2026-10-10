import 'dart:math';

import 'package:flutter/widgets.dart';

/// Ограничивает ширину содержимого и ставит его по центру, чтобы на
/// широких мониторах строки не растягивались на весь экран.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = defaultMaxWidth,
  });

  /// Удобная ширина для ленты и списков.
  static const double defaultMaxWidth = 840;

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(constraints.maxWidth, maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
