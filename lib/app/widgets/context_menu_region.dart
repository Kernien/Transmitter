import 'package:flutter/material.dart';

/// Оборачивает элемент интерфейса (карточку, строку списка, плитку),
/// чтобы по клику правой кнопкой мыши (ПКМ) на десктопе/вебе
/// или долгому нажатию (long press) на сенсорных экранах
/// открывалось контекстное меню действий с теми же опциями,
/// что и у кнопки с тремя точками (⋮).
class ContextMenuRegion<T> extends StatefulWidget {
  const ContextMenuRegion({
    super.key,
    required this.child,
    required this.itemBuilder,
    required this.onSelected,
    this.enabled = true,
  });

  final Widget child;
  final List<PopupMenuEntry<T>> Function(BuildContext context) itemBuilder;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  State<ContextMenuRegion<T>> createState() => ContextMenuRegionState<T>();
}

class ContextMenuRegionState<T> extends State<ContextMenuRegion<T>> {
  Offset? _lastPointerPosition;

  Future<void> showMenuAt([Offset? position]) async {
    if (!widget.enabled || !mounted) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final targetPos = position ?? _lastPointerPosition ?? _centerPosition();
    final relativeRect = RelativeRect.fromRect(
      Rect.fromLTWH(targetPos.dx, targetPos.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    final items = widget.itemBuilder(context);
    if (items.isEmpty) return;

    final selected = await showMenu<T>(
      context: context,
      position: relativeRect,
      items: items,
    );
    if (selected != null && mounted) {
      widget.onSelected(selected);
    }
  }

  Offset _centerPosition() {
    final box = context.findRenderObject() as RenderBox?;
    return box != null
        ? box.localToGlobal(box.size.center(Offset.zero))
        : Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _lastPointerPosition = event.position;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (details) => showMenuAt(details.globalPosition),
        onLongPress: () => showMenuAt(_lastPointerPosition),
        child: widget.child,
      ),
    );
  }
}
