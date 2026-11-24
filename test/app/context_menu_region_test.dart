import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/app/widgets/context_menu_region.dart';

void main() {
  Widget buildApp({
    required VoidCallback onTap,
    required ValueChanged<String> onSelected,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ContextMenuRegion<String>(
            enabled: enabled,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'action1', child: Text('Действие 1')),
              PopupMenuItem(value: 'action2', child: Text('Действие 2')),
            ],
            onSelected: onSelected,
            child: InkWell(
              onTap: onTap,
              child: const SizedBox(
                width: 200,
                height: 60,
                child: Text('Целевой элемент'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('обычный тап (ЛКМ) вызывает onTap и не открывает меню', (tester) async {
    var tapped = false;
    var selectedAction = '';

    await tester.pumpWidget(
      buildApp(
        onTap: () => tapped = true,
        onSelected: (val) => selectedAction = val,
      ),
    );

    await tester.tap(find.text('Целевой элемент'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(selectedAction, isEmpty);
    expect(find.text('Действие 1'), findsNothing);
  });

  testWidgets('ПКМ (secondary tap) открывает контекстное меню', (tester) async {
    var tapped = false;
    var selectedAction = '';

    await tester.pumpWidget(
      buildApp(
        onTap: () => tapped = true,
        onSelected: (val) => selectedAction = val,
      ),
    );

    // Клик правой кнопкой мыши
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Целевой элемент')),
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tapped, isFalse);
    expect(find.text('Действие 1'), findsOneWidget);
    expect(find.text('Действие 2'), findsOneWidget);

    await tester.tap(find.text('Действие 1'));
    await tester.pumpAndSettle();

    expect(selectedAction, 'action1');
  });

  testWidgets('долгий тап (long press) открывает контекстное меню', (tester) async {
    var selectedAction = '';

    await tester.pumpWidget(
      buildApp(
        onTap: () {},
        onSelected: (val) => selectedAction = val,
      ),
    );

    await tester.longPress(find.text('Целевой элемент'));
    await tester.pumpAndSettle();

    expect(find.text('Действие 2'), findsOneWidget);

    await tester.tap(find.text('Действие 2'));
    await tester.pumpAndSettle();

    expect(selectedAction, 'action2');
  });

  testWidgets('при enabled: false меню не открывается', (tester) async {
    await tester.pumpWidget(
      buildApp(
        enabled: false,
        onTap: () {},
        onSelected: (_) {},
      ),
    );

    await tester.longPress(find.text('Целевой элемент'));
    await tester.pumpAndSettle();

    expect(find.text('Действие 1'), findsNothing);
  });
}
