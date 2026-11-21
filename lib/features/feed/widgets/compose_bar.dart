import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/l10n.dart';
import '../feed_controller.dart';

/// РџРѕР»Рµ РІРІРѕРґР° Рё РєРЅРѕРїРєР° РѕС‚РїСЂР°РІРєРё РІРЅРёР·Сѓ Р»РµРЅС‚С‹.
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
    final maxFileSize = context.select<FeedController, int>((f) => f.maxFileSize);
    final canAttachMedia = context.select<FeedController, bool>((f) => f.canAttachMedia);

    // РџР°РЅРµР»СЊ РІРІРѕРґР° вЂ” РѕС‚РґРµР»СЊРЅР°СЏ Р·РѕРЅР°: С‚РѕРЅ СЃРІРµС‚Р»РµРµ Р»РµРЅС‚С‹.
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 8),
        child: Row(
          children: [
            if (canAttachMedia)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.attachMediaTooltipOf(maxFileSize),
                onPressed: sending ? null : _attachMedia,
                icon: const Icon(Icons.photo_library_outlined),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.attachFileTooltipOf(maxFileSize),
              onPressed: sending ? null : _attach,
              icon: const Icon(Icons.attach_file),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.attachFolderTooltipOf(maxFileSize),
              onPressed: sending ? null : _attachFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: context.l10n.composeHint,
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: sending ? context.l10n.cancelUpload : context.l10n.send,
              onPressed: sending
                  ? () => context.read<FeedController>().cancelActiveSend()
                  : _send,
              icon: sending
                  ? const Icon(Icons.close)
                  : const Icon(Icons.send),
            ),
          ],
        ),
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

  /// РўРµРєСЃС‚ РёР· РїРѕР»СЏ РІРІРѕРґР° СЃС‚Р°РЅРѕРІРёС‚СЃСЏ РїРѕРґРїРёСЃСЊСЋ Рє С„Р°Р№Р»Сѓ.
  Future<void> _attach() async {
    final ok = await context.read<FeedController>().attachFile(
      caption: _text.text,
    );
    if (ok) _text.clear();
  }

  Future<void> _attachFolder() async {
    final ok = await context.read<FeedController>().attachFolder(
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
