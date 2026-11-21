import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../core/vault/vault_key.dart';
import '../../data/sub_vault_store.dart';
import 'board_access_sheet.dart';
import 'share_vault_sheet.dart';
import 'vault_icon.dart';
import 'vaults_controller.dart';

enum _SubVaultAction { share, board, rename, fileSize, delete }

/// Список поддосок одного уровня. Каждый новый уровень открывается
/// обычным маршрутом, поэтому системная кнопка «Назад» сохраняет путь.
class SubVaultsScreen extends StatefulWidget {
  const SubVaultsScreen({
    super.key,
    required this.parent,
    required this.path,
    required this.remote,
    required this.buildFeed,
  });

  final VaultKey parent;
  final List<String> path;
  final SubVaultsRemote remote;
  final Widget Function(VaultKey) buildFeed;

  @override
  State<SubVaultsScreen> createState() => _SubVaultsScreenState();
}

class _SubVaultsScreenState extends State<SubVaultsScreen> {
  List<VaultKey>? _cached;
  late Future<List<VaultKey>> _children;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cached = widget.remote.cachedSubVaults(widget.parent);
    _children = _load();
  }

  Future<List<VaultKey>> _load() async {
    final children = await widget.remote.listSubVaults(widget.parent);
    if (mounted) {
      setState(() => _cached = children);
      context.read<VaultsController?>()?.rememberSubVaults(
        widget.parent,
        children,
      );
    }
    return children;
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final label = await showDialog<String>(
        context: context,
        builder: (_) => const _SubVaultNameDialog(),
      );
      if (!mounted || label == null) return;
      await widget.remote.createSubVault(widget.parent, label);
      if (mounted) setState(() => _children = _load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.describeError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(VaultKey child) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => widget.buildFeed(child)));
    if (mounted) setState(() => _children = _load());
  }

  Future<void> _onAction(VaultKey child, _SubVaultAction action) async {
    final l = context.l10n;
    switch (action) {
      case _SubVaultAction.share:
        await showShareVaultSheet(context, child);
      case _SubVaultAction.board:
        await showBoardAccessSheet(context, child);
      case _SubVaultAction.rename:
        final label = await showDialog<String>(
          context: context,
          builder: (_) => _SubVaultNameDialog(
            initialValue: child.label,
            title: l.nameTitle,
            actionLabel: l.save,
          ),
        );
        if (!mounted || label == null || label == child.label) return;
        await _runMutation(
          () => widget.remote.renameSubVault(widget.parent, child, label),
        );
      case _SubVaultAction.fileSize:
        final size = await _askFileSize(child.maxFileSize);
        if (!mounted || size == null || size == child.maxFileSize) return;
        await _runMutation(
          () => widget.remote.setSubVaultMaxFileSize(widget.parent, child, size),
        );
      case _SubVaultAction.delete:
        final confirmed = await _confirmDelete(child);
        if (!mounted || !confirmed) return;
        await _runMutation(
          () => widget.remote.deleteSubVault(widget.parent, child),
        );
    }
  }

  Future<void> _runMutation(Future<Object?> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _children = _load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.describeError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _askFileSize(int current) {
    final l = context.l10n;
    final options = [
      if (!VaultKey.maxFileSizeOptions.contains(current)) current,
      ...VaultKey.maxFileSizeOptions,
    ]..sort();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.maxFileSizeLabel),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final size in options)
                ListTile(
                  leading: Icon(
                    size == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(l.sizeLimitOf(size)),
                  onTap: () => Navigator.pop(ctx, size),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(VaultKey child) async {
    final l = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l.delete} «${child.label}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.subVaults),
        actions: [
          IconButton(
            tooltip: l.createSubVault,
            icon: const Icon(Icons.add),
            onPressed: _busy ? null : _create,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        icon: const Icon(Icons.add),
        label: Text(l.createSubVault),
      ),
      body: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.path.join(' / '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: FutureBuilder<List<VaultKey>>(
                future: _children,
                builder: (context, snapshot) {
                  final list = snapshot.data ?? _cached;
                  if (snapshot.connectionState != ConnectionState.done &&
                      list == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError && list == null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.describeError(snapshot.error!)),
                          TextButton(
                            onPressed: () =>
                                setState(() => _children = _load()),
                            child: Text(l.retry),
                          ),
                        ],
                      ),
                    );
                  }
                  final children = list ?? const <VaultKey>[];
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() => _children = _load());
                      try {
                        await _children;
                      } catch (_) {
                        // FutureBuilder показывает ошибку загрузки.
                      }
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 88),
                      children: [
                        if (children.isEmpty)
                          ListTile(title: Text(l.noSubVaults)),
                        for (final child in children)
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: ShapeDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                shape: const ContinuousRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(16)),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: VaultIcon.buildWidget(
                                child.icon,
                                isEncrypted: child.isEncrypted,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            title: Text(child.label),
                            subtitle: Text(
                              l.vaultConnectedSubtitle(
                                child,
                                context
                                    .read<VaultsController?>() ==
                                        null
                                    ? null
                                    : null,
                              ),
                            ),
                            onTap: () => _open(child),
                            trailing: PopupMenuButton<_SubVaultAction>(
                              onSelected: (action) => _onAction(child, action),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: _SubVaultAction.share,
                                  child: Text(l.showKeyQr),
                                ),
                                PopupMenuItem(
                                  value: _SubVaultAction.board,
                                  child: Text(l.boardAccessAction),
                                ),
                                PopupMenuItem(
                                  value: _SubVaultAction.rename,
                                  child: Text(l.rename),
                                ),
                                PopupMenuItem(
                                  value: _SubVaultAction.fileSize,
                                  child: Text(l.fileSizeAction),
                                ),
                                PopupMenuItem(
                                  value: _SubVaultAction.delete,
                                  child: Text(l.delete),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubVaultNameDialog extends StatefulWidget {
  const _SubVaultNameDialog({
    this.initialValue = '',
    this.title,
    this.actionLabel,
  });

  final String initialValue;
  final String? title;
  final String? actionLabel;

  @override
  State<_SubVaultNameDialog> createState() => _SubVaultNameDialogState();
}

class _SubVaultNameDialogState extends State<_SubVaultNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  late String _name = widget.initialValue.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title ?? l.createSubVault),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l.nameTitle),
        onChanged: (value) => setState(() => _name = value.trim()),
        onSubmitted: (_) {
          if (_name.isNotEmpty) Navigator.of(context).pop(_name);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _name.isEmpty
              ? null
              : () => Navigator.of(context).pop(_name),
          child: Text(widget.actionLabel ?? l.create),
        ),
      ],
    );
  }
}
