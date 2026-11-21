import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import 'vault_icon.dart';

/// Диалог выбора значка доски (Material-иконка или эмодзи).
class SelectVaultIconDialog extends StatefulWidget {
  const SelectVaultIconDialog({super.key, this.initialIcon});

  final String? initialIcon;

  static Future<String?> show(BuildContext context, {String? initialIcon}) {
    return showDialog<String?>(
      context: context,
      builder: (_) => SelectVaultIconDialog(initialIcon: initialIcon),
    );
  }

  @override
  State<SelectVaultIconDialog> createState() => _SelectVaultIconDialogState();
}

class _SelectVaultIconDialogState extends State<SelectVaultIconDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _customEmojiController;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIcon;
    _tabController = TabController(length: 2, vsync: this);
    _customEmojiController = TextEditingController();

    // Если начальный значок не из каталога, это эмодзи
    if (_selected != null && !VaultIcon.catalog.containsKey(_selected)) {
      _tabController.index = 1;
      _customEmojiController.text = _selected!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customEmojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(l.selectIconTitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: SizedBox(
        width: 340,
        height: 380,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(Icons.category_outlined, size: 20),
                  text: l.iconsTab,
                ),
                Tab(
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 20),
                  text: l.emojisTab,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIconsGrid(colorScheme),
                  _buildEmojisGrid(colorScheme, l),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''), // Сброс по умолчанию
          child: Text(l.resetToDefault),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(l.save),
        ),
      ],
    );
  }

  Widget _buildIconsGrid(ColorScheme colorScheme) {
    final entries = VaultIcon.catalog.entries.toList();
    return GridView.builder(
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, i) {
        final key = entries[i].key;
        final icon = entries[i].value;
        final isSelected = _selected == key;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selected = key;
              _customEmojiController.clear();
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojisGrid(ColorScheme colorScheme, AppLocalizations l) {
    return Column(
      children: [
        TextField(
          controller: _customEmojiController,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22),
          decoration: InputDecoration(
            counterText: '',
            hintText: l.customEmojiHint,
            prefixIcon: const Icon(Icons.edit_outlined, size: 18),
            isDense: true,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) {
            final trimmed = val.trim();
            setState(() {
              _selected = trimmed.isEmpty ? null : trimmed;
            });
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            itemCount: VaultIcon.popularEmojis.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, i) {
              final emoji = VaultIcon.popularEmojis[i];
              final isSelected = _selected == emoji;

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    _selected = emoji;
                    _customEmojiController.text = emoji;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20, height: 1),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
