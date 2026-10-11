import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/language_controller.dart';

/// Выбор языка интерфейса: как в системе, русский или английский.
/// Языки подписаны на них самих, чтобы их было легко найти.
Future<void> showLanguageDialog(BuildContext context) {
  final controller = context.read<LanguageController>();
  return showDialog<void>(
    context: context,
    builder: (context) => ChangeNotifierProvider.value(
      value: controller,
      child: const _LanguageDialog(),
    ),
  );
}

class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = context.watch<LanguageController>();
    return AlertDialog(
      title: Text(l.language),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: RadioGroup<AppLanguage>(
        groupValue: controller.language,
        onChanged: (language) {
          if (language != null) controller.select(language);
          Navigator.pop(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in AppLanguage.values)
              RadioListTile<AppLanguage>(
                value: language,
                title: Text(
                  language == AppLanguage.system
                      ? l.languageSystem
                      : language.nativeName,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
