import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transmitter/app/widgets/splash_screen.dart';

void main() {
  testWidgets('экран запуска: знак на индиго, без MaterialApp', (tester) async {
    // Показывается первым, до MaterialApp: никакой темы и локализации нет.
    await tester.pumpWidget(const SplashScreen());

    final background = tester.widget<ColoredBox>(find.byType(ColoredBox));
    expect(background.color, SplashScreen.background);
    final logo = tester.widget<Image>(find.byType(Image));
    expect((logo.image as AssetImage).assetName, 'assets/branding/splash.png');
    expect(find.bySemanticsLabel('Transmitter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
