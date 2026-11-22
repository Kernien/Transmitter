import 'package:flutter/material.dart';

/// Аккуратное и выразительное пустое состояние экрана (Empty State).
///
/// Отображает центрированную иконку в мягком скругленном контейнере,
/// заголовок, пояснительный текст и опциональное действие.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconBoxSize = compact ? 56.0 : 72.0;
    final iconSize = compact ? 28.0 : 36.0;
    final borderRadius = compact ? 20.0 : 26.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 24,
          vertical: compact ? 20 : 32,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 280 : 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: ShapeDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.65,
                  ),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.85,
                  ),
                ),
              ),
              SizedBox(height: compact ? 14 : 18),
              Text(
                title,
                style: (compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle case final text?) ...[
                const SizedBox(height: 8),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action case final act?) ...[
                SizedBox(height: compact ? 16 : 20),
                act,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
