import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_lock_controller.dart';
import '../../app/l10n.dart';
import '../../app/widgets/content_width.dart';
import '../../app/vault_session_factory.dart';
import '../../core/storage/cloud_connection_service.dart';
import '../../core/vault/reader_key.dart';
import '../../core/vault/vault_key.dart';
import '../cloud_connect/connect_cloud_screen.dart';
import '../feed/feed_screen.dart';
import '../settings/settings_sheet.dart';
import 'board_access_sheet.dart';
import 'create_vault_dialog.dart';
import 'import_vault_screen.dart';
import 'share_vault_sheet.dart';
import 'vaults_controller.dart';

/// Порог ширины окна, начиная с которого список досок и открытая лента
/// показываются рядом в двух панелях (Master-Detail).
const double kWideScreenBreakpoint = 840;

/// Ширина левой панели со списком досок на широком экране.
const double _kMasterPaneWidth = 360;

/// Главный экран: список ключей баз (на широком мониторе — вместе с открытой лентой).
class VaultsScreen extends StatefulWidget {
  const VaultsScreen({super.key});

  @override
  State<VaultsScreen> createState() => _VaultsScreenState();
}

class _VaultsScreenState extends State<VaultsScreen> {
  bool _didOpenPinned = false;

  /// Идентификатор выбранной доски в двухпанельном режиме (`VaultsController.idOfKey`).
  String? _selectedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkOpenPinned();
  }

  void _checkOpenPinned() {
    if (_didOpenPinned) return;
    final appLock = Provider.of<AppLockController?>(context);
    if (appLock != null && appLock.isLocked) return;

    final controller = context.read<VaultsController>();
    final pinnedVault = controller.pinnedVault;
    final pinnedBoard = controller.pinnedBoard;

    if (pinnedVault != null || pinnedBoard != null) {
      _didOpenPinned = true;
      final isWide = MediaQuery.sizeOf(context).width >= kWideScreenBreakpoint;
      if (isWide) {
        if (pinnedVault != null) {
          final connections = context.read<CloudConnectionService>();
          if (connections.isSupported(pinnedVault.provider) &&
              connections.isConnected(pinnedVault.provider)) {
            _selectedId = VaultsController.idOfKey(pinnedVault);
            return;
          }
        } else if (pinnedBoard != null) {
          _selectedId = VaultsController.idOfKey(pinnedBoard);
          return;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (pinnedVault != null) {
          _selectVault(pinnedVault);
        } else if (pinnedBoard != null) {
          _selectBoard(pinnedBoard);
        }
      });
    }
  }

  /// Находит актуальный объект доски ([VaultKey] или [ReaderKey]) по [_selectedId].
  Object? _resolveSelected(
    List<VaultKey> vaults,
    List<ReaderKey> boards,
  ) {
    final id = _selectedId;
    if (id == null) return null;
    for (final v in vaults) {
      if (VaultsController.idOfKey(v) == id) return v;
    }
    for (final b in boards) {
      if (VaultsController.idOfKey(b) == id) return b;
    }
    return null;
  }

  Future<void> _selectVault(VaultKey vault) async {
    final isWide = MediaQuery.sizeOf(context).width >= kWideScreenBreakpoint;
    if (!isWide) {
      await openVault(context, vault);
      return;
    }
    final connections = context.read<CloudConnectionService>();
    final messenger = ScaffoldMessenger.of(context);
    if (!connections.isSupported(vault.provider)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.providerNotSupported(vault.provider.title)),
        ),
      );
      return;
    }
    if (!connections.isConnected(vault.provider)) {
      final connected = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ConnectCloudScreen(provider: vault.provider),
        ),
      );
      if (connected != true || !mounted) return;
    }
    final nextId = VaultsController.idOfKey(vault);
    if (_selectedId != nextId) {
      setState(() => _selectedId = nextId);
    }
    unawaited(context.read<VaultsController>().refreshSettings(only: vault));
  }

  Future<void> _selectBoard(ReaderKey board) async {
    final isWide = MediaQuery.sizeOf(context).width >= kWideScreenBreakpoint;
    if (!isWide) {
      await openBoard(context, board);
      return;
    }
    final nextId = VaultsController.idOfKey(board);
    if (_selectedId != nextId) {
      setState(() => _selectedId = nextId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = context.watch<VaultsController>();
    final vaults = controller.vaults;
    final boards = controller.boards;
    final isWide = MediaQuery.sizeOf(context).width >= kWideScreenBreakpoint;
    final selected = isWide ? _resolveSelected(vaults, boards) : null;

    Widget buildList() {
      if (vaults.isEmpty && boards.isEmpty) {
        return const _EmptyState();
      }
      return ListView.separated(
        itemCount: vaults.length + boards.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i < vaults.length) {
            final v = vaults[i];
            return _VaultTile(
              vault: v,
              selected:
                  isWide && _selectedId == VaultsController.idOfKey(v),
              onTap: () => _selectVault(v),
            );
          } else {
            final b = boards[i - vaults.length];
            return _BoardTile(
              board: b,
              selected:
                  isWide && _selectedId == VaultsController.idOfKey(b),
              onTap: () => _selectBoard(b),
            );
          }
        },
      );
    }

    final appBarActions = [
      // Оформление, язык и место на устройстве — в «Настройках».
      IconButton(
        tooltip: l.settings,
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => showSettingsSheet(context),
      ),
      IconButton(
        tooltip: l.addKey,
        icon: const Icon(Icons.qr_code_scanner),
        onPressed: () => _import(context),
      ),
    ];

    final fab = FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: Text(l.newKey),
      onPressed: () => _create(context),
    );

    if (!isWide) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Transmitter'),
          actions: appBarActions,
        ),
        body: ContentWidth(child: buildList()),
        floatingActionButton: fab,
      );
    }

    return Row(
      children: [
        SizedBox(
          width: _kMasterPaneWidth,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Transmitter'),
              actions: appBarActions,
            ),
            body: buildList(),
            floatingActionButton: fab,
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: switch (selected) {
            VaultKey v => FeedScreen.vault(
              v,
              key: ValueKey(VaultsController.idOfKey(v)),
              embedded: true,
            ),
            ReaderKey b => FeedScreen.board(
              b,
              key: ValueKey(VaultsController.idOfKey(b)),
              embedded: true,
              liveLabel: (context) =>
                  context.watch<VaultsController>().boardLabel(b),
              onOwnerLabel: (label) => controller.applyOwnerLabel(b, label),
            ),
            _ => Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l.selectBoardHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          },
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context) async {
    final key = await showDialog<VaultKey>(
      context: context,
      builder: (_) => const CreateVaultDialog(),
    );
    if (key != null && context.mounted) {
      await showShareVaultSheet(context, key);
    }
  }

  Future<void> _import(BuildContext context) async {
    final key = await Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => const ImportVaultScreen()),
    );
    if (!context.mounted) return;
    switch (key) {
      case VaultKey():
        await _selectVault(key);
      case ReaderKey():
        await _selectBoard(key);
    }
  }
}

/// Открывает базу. Если облако ещё не подключено, сначала просит войти.
Future<void> openVault(BuildContext context, VaultKey key) async {
  final connections = context.read<CloudConnectionService>();
  final messenger = ScaffoldMessenger.of(context);

  if (!connections.isSupported(key.provider)) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.providerNotSupported(key.provider.title)),
      ),
    );
    return;
  }
  if (!connections.isConnected(key.provider)) {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConnectCloudScreen(provider: key.provider),
      ),
    );
    if (connected != true || !context.mounted) return;
  }
  final vaults = context.read<VaultsController>();
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => FeedScreen.vault(key)));
  // Пока лента была открыта, название или лимит могли поменять на другом
  // устройстве (а облако — только что подключить).
  unawaited(vaults.refreshSettings(only: key));
}

/// Открывает публичную доску для чтения — вход в облако не нужен.
Future<void> openBoard(BuildContext context, ReaderKey key) {
  final vaults = context.read<VaultsController>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FeedScreen.board(
        key,
        liveLabel: (context) =>
            context.watch<VaultsController>().boardLabel(key),
        onOwnerLabel: (label) => vaults.applyOwnerLabel(key, label),
      ),
    ),
  );
}

class _VaultTile extends StatelessWidget {
  const _VaultTile({
    required this.vault,
    this.selected = false,
    this.onTap,
  });

  final VaultKey vault;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = context.watch<VaultsController>();
    final isPinned = controller.isPinned(vault);
    final connected = context.watch<CloudConnectionService>().isConnected(
      vault.provider,
    );
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
      leading: CircleAvatar(
        child: Icon(vault.isEncrypted ? Icons.key : Icons.folder_open_outlined),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              vault.label.isEmpty ? l.untitled : vault.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPinned)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.push_pin,
                size: 16,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),
      subtitle: Text(
        connected
            ? l.vaultConnectedSubtitle(vault)
            : (vault.isEncrypted
                  ? l.vaultSubtitleNotConnected(vault.provider.title)
                  : l.vaultSubtitleNotConnectedPlain(vault.provider.title)),
      ),
      onTap: onTap ?? () => openVault(context, vault),
      trailing: PopupMenuButton<_VaultAction>(
        onSelected: (action) => _onAction(context, action),
        itemBuilder: (_) => [
          PopupMenuItem(value: _VaultAction.share, child: Text(l.showKeyQr)),
          PopupMenuItem(
            value: _VaultAction.board,
            child: Text(l.boardAccessAction),
          ),
          PopupMenuItem(
            value: _VaultAction.pin,
            child: Text(isPinned ? l.unpinVault : l.pinVault),
          ),
          PopupMenuItem(value: _VaultAction.rename, child: Text(l.rename)),
          PopupMenuItem(
            value: _VaultAction.fileSize,
            child: Text(l.fileSizeAction),
          ),
          PopupMenuItem(
            value: _VaultAction.remove,
            child: Text(l.removeFromDevice),
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, _VaultAction action) async {
    final controller = context.read<VaultsController>();
    switch (action) {
      case _VaultAction.share:
        await showShareVaultSheet(context, vault);
      case _VaultAction.board:
        await showBoardAccessSheet(context, vault);
      case _VaultAction.pin:
        await controller.togglePinned(vault);
      case _VaultAction.rename:
        final label = await _askLabel(context, vault.label);
        if (label == null || !context.mounted) return;
        if (!await _saveChange(context, controller.rename(vault, label))) {
          return;
        }
        if (context.mounted) await _renameBoard(context, label.trim());
      case _VaultAction.fileSize:
        final size = await _askFileSize(context, vault.maxFileSize);
        if (size == null || size == vault.maxFileSize || !context.mounted) {
          return;
        }
        await _saveChange(context, controller.setMaxFileSize(vault, size));
      case _VaultAction.remove:
        if (await _confirmRemove(context)) await controller.remove(vault);
    }
  }

  /// Название и лимит общие для устройств базы и сохраняются в облаке: без
  /// связи с ним изменение не проходит — показываем почему.
  static Future<bool> _saveChange(
    BuildContext context,
    Future<void> change,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await change;
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.vaultChangeFailed(l.describeError(e)))),
      );
      return false;
    }
  }

  /// Если у базы открыт доступ на чтение, читатели увидят новое название.
  Future<void> _renameBoard(BuildContext context, String label) async {
    final connections = context.read<CloudConnectionService>();
    if (!connections.isConnected(vault.provider)) return;
    final sessions = context.read<VaultSessionFactory>();
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    try {
      await (await sessions.openBoard(vault))?.rename(label);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.boardRenameFailed(l.describeError(e)))),
      );
    }
  }

  Future<bool> _confirmRemove(BuildContext context) async {
    final l = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.removeKeyTitle),
        content: Text(l.removeKeyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Спрашивает новое название базы или доски.
Future<String?> _askLabel(BuildContext context, String current) {
  final l = context.l10n;
  final text = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.nameTitle),
      content: TextField(controller: text, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, text.text),
          child: Text(l.save),
        ),
      ],
    ),
  );
}

/// Спрашивает новый лимит размера файла.
Future<int?> _askFileSize(BuildContext context, int current) {
  final l = context.l10n;
  final options = [
    if (!VaultKey.maxFileSizeOptions.contains(current)) current,
    ...VaultKey.maxFileSizeOptions,
  ]..sort();
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.maxFileSizeLabel),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(l.fileSizeHelp),
            ),
            const SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: current,
              onChanged: (size) => Navigator.pop(context, size),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final size in options)
                    RadioListTile<int>(
                      value: size,
                      title: Text(l.sizeLimitOf(size)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
      ],
    ),
  );
}

enum _VaultAction { share, board, pin, rename, fileSize, remove }

/// Публичная доска, которую на этом устройстве можно только читать.
class _BoardTile extends StatelessWidget {
  const _BoardTile({
    required this.board,
    this.selected = false,
    this.onTap,
  });

  final ReaderKey board;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = context.watch<VaultsController>();
    final isPinned = controller.isPinned(board);
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
      leading: const CircleAvatar(child: Icon(Icons.public)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              board.label.isEmpty ? l.untitled : board.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPinned)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.push_pin,
                size: 16,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),
      subtitle: Text(l.boardSubtitle(board.provider.title)),
      onTap: onTap ?? () => openBoard(context, board),
      trailing: PopupMenuButton<_BoardAction>(
        onSelected: (action) => _onAction(context, action),
        itemBuilder: (_) => [
          PopupMenuItem(value: _BoardAction.share, child: Text(l.showKeyQr)),
          PopupMenuItem(
            value: _BoardAction.pin,
            child: Text(isPinned ? l.unpinVault : l.pinVault),
          ),
          PopupMenuItem(value: _BoardAction.rename, child: Text(l.rename)),
          PopupMenuItem(
            value: _BoardAction.remove,
            child: Text(l.removeFromDevice),
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, _BoardAction action) async {
    final controller = context.read<VaultsController>();
    final l = context.l10n;
    switch (action) {
      case _BoardAction.share:
        await showReaderKeySheet(context, board);
      case _BoardAction.pin:
        await controller.togglePinned(board);
      case _BoardAction.rename:
        final label = await _askLabel(context, board.label);
        if (label != null) await controller.renameBoard(board, label);
      case _BoardAction.remove:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.removeKeyTitle),
            content: Text(l.removeBoardText),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.delete),
              ),
            ],
          ),
        );
        if (confirmed == true) await controller.removeBoard(board);
    }
  }
}

enum _BoardAction { share, pin, rename, remove }

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(context.l10n.vaultsEmpty, textAlign: TextAlign.center),
      ),
    );
  }
}
