import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../feed_controller.dart';

/// Поле ввода и кнопка отправки внизу ленты.
class ComposeBar extends StatefulWidget {
  const ComposeBar({super.key});

  @override
  State<ComposeBar> createState() => _ComposeBarState();
}

class _ComposeBarState extends State<ComposeBar> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sending = context.select<FeedController, bool>((f) => f.isSending);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Сообщение или ссылка',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Отправить',
              onPressed: sending ? null : _send,
              icon: sending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    final ok = await context.read<FeedController>().sendText(text);
    if (ok) _text.clear();
  }
}
