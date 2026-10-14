import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/l10n.dart';
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
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
        child: Row(
          children: [
            if (context.read<FeedController>().canAttachMedia)
              IconButton(
                tooltip: context.l10n.attachMediaTooltip(
                  context.l10n.sizeLimitOf(
                    context.read<FeedController>().maxFileSize,
                  ),
                ),
                onPressed: sending ? null : _attachMedia,
                icon: const Icon(Icons.photo_library_outlined),
              ),
            IconButton(
              tooltip: context.l10n.attachFileTooltip(
                context.l10n.sizeLimitOf(
                  context.read<FeedController>().maxFileSize,
                ),
              ),
              onPressed: sending ? null : _attach,
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: context.l10n.composeHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: context.l10n.send,
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

  /// Текст из поля ввода становится подписью к файлу.
  Future<void> _attach() async {
    final ok = await context.read<FeedController>().attachFile(
      caption: _text.text,
    );
    if (ok) _text.clear();
  }

  Future<void> _attachMedia() async {
    final ok = await context.read<FeedController>().attachMedia(
      caption: _text.text,
    );
    if (ok) _text.clear();
  }
}
