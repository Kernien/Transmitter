import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets/content_width.dart';
import '../../core/share/incoming_share.dart';
import '../../core/utils/format_size.dart';
import 'share_target_controller.dart';

/// «Отправить в Transmitter»: что пришло из другого приложения и куда отправить.
/// Возвращает `true`, если всё отправлено.
class ShareTargetScreen extends StatelessWidget {
  const ShareTargetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ShareTargetController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Отправить в Transmitter')),
      body: ContentWidth(
        maxWidth: 600,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Preview(content: c.content),
            const SizedBox(height: 24),
            Text('Куда отправить', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (c.vaults.isEmpty)
              const Text('Сначала создайте ключ базы в Transmitter.')
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
                        title: Text(
                          key.label.isEmpty ? 'Без названия' : key.label,
                        ),
                        subtitle: Text(
                          c.isUsable(key)
                              ? key.provider.title
                              : '${key.provider.title} · сначала войдите в облако',
                        ),
                      ),
                  ],
                ),
              ),
            if (c.error != null) ...[
              const SizedBox(height: 16),
              Text(c.error!, style: TextStyle(color: theme.colorScheme.error)),
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
                  ? 'Отправка ${c.sentCount + 1} из ${c.totalCount}…'
                  : 'Отправить',
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
                  file.isTooLarge
                      ? Icons.block
                      : Icons.insert_drive_file_outlined,
                  color: file.isTooLarge ? theme.colorScheme.error : null,
                ),
                title: Text(file.name),
                subtitle: Text(
                  file.isTooLarge
                      ? 'Больше 25 МБ — не будет отправлен'
                      : formatFileSize(file.size),
                  style: file.isTooLarge
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
