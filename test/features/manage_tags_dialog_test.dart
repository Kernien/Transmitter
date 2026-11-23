import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/features/vaults/manage_tags_dialog.dart';
import 'package:transmitter/l10n/app_localizations.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(body: child),
    );
  }

  testWidgets('ManageTagsDialog: отображение тегов, добавление и сохранение', (
    tester,
  ) async {
    List<String>? result;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ManageTagsDialog.show(
                context,
                initialTags: ['Работа'],
                availableTags: ['Работа', 'Проект', 'Архив'],
              );
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    // Начальный тег виден
    expect(find.text('#Работа'), findsOneWidget);
    // Доступные теги, которых нет в начальных
    expect(find.text('#Проект'), findsOneWidget);
    expect(find.text('#Архив'), findsOneWidget);

    // Добавляем тег кликом по подсказке
    await tester.tap(find.text('#Проект'));
    await tester.pumpAndSettle();

    // Вводим новый тег через поле ввода
    await tester.enterText(find.byType(TextField), '  #Клиенты  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('#Клиенты'), findsOneWidget);

    // Сохраняем
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(result, ['Работа', 'Проект', 'Клиенты']);
  });

  testWidgets('ManageTagsDialog: удаление тега', (tester) async {
    List<String>? result;

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ManageTagsDialog.show(
                context,
                initialTags: ['Работа', 'Архив'],
                availableTags: ['Работа', 'Архив'],
              );
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    // Удаляем тег 'Работа' нажатием на крестик
    final deleteButtons = find.byIcon(Icons.close);
    expect(deleteButtons, findsNWidgets(2));
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(InputChip),
        matching: find.text('#Работа'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(InputChip),
        matching: find.text('#Архив'),
      ),
      findsOneWidget,
    );

    // Сохраняем
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(result, ['Архив']);
  });

  testWidgets('ManageTagsDialog: отмена не возвращает результат', (tester) async {
    List<String>? result = ['some'];

    await tester.pumpWidget(
      buildApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await ManageTagsDialog.show(
                context,
                initialTags: ['Работа'],
                availableTags: ['Работа'],
              );
            },
            child: const Text('Открыть'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
