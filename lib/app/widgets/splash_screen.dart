import 'package:flutter/widgets.dart';

/// Экран запуска: индиго и белый знак по центру — пока приложение загружает
/// ключи и настройки. Такой же системный экран на Android и в вебе
/// (flutter_native_splash.yaml); на Windows и Linux системного нет, там
/// показывается этот.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Цвет логотипа (assets/branding).
  static const Color background = Color(0xFF3F51B5);

  @override
  // Показывается до MaterialApp: направление текста (для подписи знака)
  // задаём сами.
  Widget build(BuildContext context) => const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: background,
      child: Center(
        child: Image(
          image: AssetImage('assets/branding/splash.png'),
          width: 160,
          height: 160,
          semanticLabel: 'Transmitter',
        ),
      ),
    ),
  );
}
