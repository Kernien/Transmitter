import 'dart:math';

import 'package:flutter/material.dart';

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

/// Оборачивает полноэкранную страницу ([Scaffold] с собственной шапкой) в
/// центрированную колонку на широких мониторах, чтобы шапка, кнопки и
/// содержимое не разъезжались по краям экрана.
class CenteredPageFrame extends StatelessWidget {
  const CenteredPageFrame({
    super.key,
    required this.child,
    this.maxWidth = ContentWidth.defaultMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        final theme = Theme.of(context);
        return ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    vertical: BorderSide(color: theme.dividerColor, width: 1),
                  ),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
