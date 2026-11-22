import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/app/widgets/empty_state_view.dart';

void main() {
  testWidgets('EmptyStateView отображает иконку, заголовок, подзаголовок и действие', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateView(
            icon: Icons.forum_outlined,
            title: 'Лента пуста',
            subtitle: 'Отправьте первое сообщение',
            action: ElevatedButton(
              onPressed: () => pressed = true,
              child: const Text('Создать'),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
    expect(find.text('Лента пуста'), findsOneWidget);
    expect(find.text('Отправьте первое сообщение'), findsOneWidget);
    expect(find.text('Создать'), findsOneWidget);

    await tester.tap(find.text('Создать'));
    expect(pressed, isTrue);
  });

  testWidgets('EmptyStateView компактный режим работает без переполнений', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 300,
            child: EmptyStateView(
              compact: true,
              icon: Icons.search_off_outlined,
              title: 'Ничего не найдено',
              subtitle: 'Попробуйте изменить запрос',
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);
    expect(find.text('Ничего не найдено'), findsOneWidget);
    expect(find.text('Попробуйте изменить запрос'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
