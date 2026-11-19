import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../core/vault/vault_key.dart';
import '../../data/sub_vault_store.dart';
import 'board_access_sheet.dart';
import 'share_vault_sheet.dart';
import 'vaults_controller.dart';

/// Список поддосок одного уровня. Каждый новый уровень открывается
/// обычным маршрутом, поэтому системная кнопка «Назад» сохраняет путь.
class SubVaultsScreen extends StatefulWidget {
  const SubVaultsScreen({
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
  late Future<List<VaultKey>> _children = _load();
  bool _creating = false;

  Future<List<VaultKey>> _load() async {
    final children = await widget.remote.listSubVaults(widget.parent);
    if (mounted) {
      context.read<VaultsController>().rememberSubVaults(
        widget.parent,
        children,
      );
    }
    return children;
  }

  Future<void> _create() async {
    setState(() => _creating = true);
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
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _open(VaultKey child) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => widget.buildFeed(child)));
    if (mounted) setState(() => _children = _load());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.subVaults),
        actions: [
          IconButton(
            tooltip: l.createSubVault,
            icon: const Icon(Icons.add),
            onPressed: _creating ? null : _create,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.path.join(' / ')),
          ),
          if (_creating) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<VaultKey>>(
              future: _children,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.describeError(snapshot.error!)),
                        TextButton(
                          onPressed: () => setState(() => _children = _load()),
                          child: Text(l.retry),
                        ),
                      ],
                    ),
                  );
                }
                final children = snapshot.requireData;
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
                    children: [
                      if (children.isEmpty)
                        ListTile(title: Text(l.noSubVaults)),
                      for (final child in children)
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: Text(child.label),
                          onTap: () => _open(child),
                          trailing: PopupMenuButton<bool>(
                            onSelected: (shareKey) {
                              if (shareKey) {
                                showShareVaultSheet(context, child);
                              } else {
                                showBoardAccessSheet(context, child);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: true, child: Text(l.share)),
                              PopupMenuItem(
                                value: false,
                                child: Text(l.boardAccessAction),
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
    );
  }
}

class _SubVaultNameDialog extends StatefulWidget {
  const _SubVaultNameDialog();

  @override
  State<_SubVaultNameDialog> createState() => _SubVaultNameDialogState();
}

class _SubVaultNameDialogState extends State<_SubVaultNameDialog> {
  String _name = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.createSubVault),
      content: TextField(
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
          child: Text(l.create),
        ),
      ],
    );
  }
}
