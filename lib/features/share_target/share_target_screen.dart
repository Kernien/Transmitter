import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../core/share/incoming_share.dart';
import 'share_target_controller.dart';

/// «Отправить в Transmitter»: что пришло из другого приложения и куда отправить.
/// Возвращает `true`, если всё отправлено.
class ShareTargetScreen extends StatelessWidget {
  const ShareTargetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = context.watch<ShareTargetController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.shareTargetTitle)),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Preview(content: c.content),
            const SizedBox(height: 24),
            Text(l.sendTo, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (c.vaults.isEmpty)
              Text(l.noVaultsYet)
            else
              RadioGroup(
                groupValue: c.selected,
                onChanged: (key) => key == null ? null : c.select(key),
                child: Column(
                  children: [
                    for (final key in c.vaults)
                      RadioListTile(
                        value: key,
                        enabled: c.isUsable(key) && !c.isSending,
                        title: Text(key.label.isEmpty ? l.untitled : key.label),
                        subtitle: Text(
                          c.isUsable(key)
                              ? l.vaultSubtitleConnected(
                                  key.provider.title,
                                  l.sizeLimitOf(key.maxFileSize),
                                )
                              : l.vaultNeedsSignIn(key.provider.title),
                        ),
                      ),
                  ],
                ),
              ),
            if (c.error != null) ...[
              const SizedBox(height: 16),
              Text(
                l.describeError(c.error!),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: c.isSending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(
              c.isSending
                  ? l.sendingProgress(c.sentCount + 1, c.totalCount)
                  : l.send,
            ),
            onPressed: c.canSend ? () => _send(context) : null,
          ),
        ),
      ),
    );
  }

  Future<void> _send(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (await context.read<ShareTargetController>().send()) navigator.pop(true);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.content});

  final SharedContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.watch<ShareTargetController>();
    final l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.hasText)
              Text(
                content.text!.trim(),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            if (content.hasText && content.files.isNotEmpty)
              const Divider(height: 24),
            for (final file in content.files)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  c.isSkipped(file)
                      ? Icons.block
                      : Icons.insert_drive_file_outlined,
                  color: c.isSkipped(file) ? theme.colorScheme.error : null,
                ),
                title: Text(file.name),
                subtitle: Text(
                  c.isSkipped(file)
                      ? l.fileSkipped(l.sizeLimitOf(c.maxFileSize))
                      : l.fileSize(file.size),
                  style: c.isSkipped(file)
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
