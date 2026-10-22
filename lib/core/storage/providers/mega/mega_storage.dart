import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../errors/app_error.dart';
import '../../cloud_storage.dart';
import '../../public_sharing.dart';
import 'mega_aes.dart';
import 'mega_api.dart';
import 'mega_crypto.dart';
import 'mega_links.dart';
import 'mega_session.dart';

/// Хранилище в MEGA: папка «Transmitter» в корне облачного диска.
///
/// У MEGA нет запросов «файлы в папке»: дерево узлов загружается целиком
/// (`f`), а дальше обновляется по журналу изменений (`/sc`). Имена узлов
/// зашифрованы и расшифровываются только для нужных папок.
///
/// Для публичных досок открывается по ссылке папка с файлом
/// ([MegaFolderLink]): у папки появляется общий ключ, и ключ каждого файла
/// в ней передаётся ещё и зашифрованным этим ключом (`cr`) — так читатель
/// расшифрует файлы, а перезапись не ломает ссылку.
class MegaStorage implements CloudStorage, PublicSharing {
  MegaStorage({
    required this._api,
    required MegaCredentials credentials,
    @visibleForTesting this.pollInterval = const Duration(seconds: 3),
    @visibleForTesting DateTime Function()? clock,
  }) : _credentials = credentials,
       _master = MegaAes(credentials.masterKey),
       _clock = clock ?? DateTime.now {
    _api.sid = credentials.sessionId;
  }

  /// Папка приложения в корне облачного диска.
  static const String appFolderName = 'Transmitter';

  /// Кусок загрузки: несколько кусков MAC, не больше ~8 МБ.
  static const int _uploadPieceBytes = 8 * 1024 * 1024;

  final MegaApi _api;
  final MegaCredentials _credentials;
  final MegaAes _master;
  final DateTime Function() _clock;

  /// Как часто, не чаще, спрашивать сервер об изменениях.
  final Duration pollInterval;

  final Map<String, _Node> _nodes = {};
  final Map<String, Set<String>> _children = {};
  String? _rootHandle;
  String? _sn;
  DateTime? _lastSync;
  Future<void>? _syncing;

  /// Папки, открытые по ссылке (общий ключ `EXP`), и публичные дескрипторы
  /// узлов.
  final Set<String> _exported = {};
  final Map<String, String> _publicHandles = {};
  final Map<String, Uint8List> _shareKeys = {};

  /// Журнал сообщил об изменении ссылок — дерево загрузим заново.
  bool _sharingChanged = false;

  /// Изменения дерева (создание папок, загрузка) — по одному, чтобы не
  /// появлялись папки-двойники.
  Future<void> _queue = Future.value();

  @override
  Future<void> ensureFolder(String path) =>
      _serial(() async => _folderHandle(path, create: true));

  @override
  Future<List<RemoteFile>> listFiles(String folder) async {
    await _sync();
    final handle = await _folderHandle(folder, create: false);
    if (handle == null) return const [];
    return [
      for (final node in _latestByName(handle).values)
        RemoteFile(name: node.name!, size: node.size),
    ];
  }

  @override
  Future<void> upload(String path, Uint8List bytes) => _serial(() async {
    final (folder, name) = _split(path);
    final parent = (await _folderHandle(folder, create: true))!;
    final key = MegaCrypto.randomBytes(16);
    final nonce = MegaCrypto.randomBytes(8);
    final encrypted = kIsWeb || bytes.length < 256 * 1024
        ? MegaCrypto.encryptFile(bytes, key, nonce)
        : await compute(_encryptJob, (bytes, key, nonce));

    final target = await _request({
      'a': 'u',
      's': bytes.length,
      'ssl': 2,
      'v': 2,
      'ms': 0,
      'r': 0,
      'e': 0,
    });
    final url = (target as Map)['p'];
    if (url is! String) {
      throw const StorageException(ErrorCode.cloudNoUploadUrl, {
        'provider': 'MEGA',
      });
    }
    final completion = MegaCrypto.b64(await _uploadPieces(url, encrypted.data));

    final fileKey = MegaCrypto.packFileKey(key, nonce, encrypted.mac);
    final result = await _request({
      'a': 'p',
      't': parent,
      'n': [
        {
          'h': completion,
          't': 0,
          'a': MegaCrypto.encryptAttributes({'n': name}, key),
          'k': MegaCrypto.b64(_master.encryptEcb(fileKey)),
        },
      ],
      'cr': ?await _keysForReaders(parent, completion, fileKey),
    });
    final added = _addNodes(result);
    // Перезапись: прежние версии с тем же именем удаляются.
    for (final old in _childrenNamed(parent, name)) {
      if (!added.contains(old.handle)) await _deleteNode(old.handle);
    }
  });

  @override
  Future<Uint8List> download(String path) async {
    var node = await _findFile(path);
    if (node == null) {
      // Файл мог появиться только что: спросим сервер ещё раз.
      await _sync(force: true);
      node = await _findFile(path);
    }
    if (node == null) throw StorageNotFoundException(path);
    final info = await _request({
      'a': 'g',
      'g': 1,
      'ssl': 2,
      'n': node.handle,
    }, path: path);
    if (info is! Map) throw StorageException.request('MEGA', 'g');
    final error = info['e'];
    if (error is int && error < 0) throw megaStorageError(error, path: path);
    final url = info['g'];
    if (url is! String) throw StorageNotFoundException(path);
    final encrypted = await _api.downloadBytes(url);
    final nodeKey = node.key!;
    final args = (
      encrypted,
      MegaCrypto.fileAesKey(nodeKey),
      Uint8List.sublistView(nodeKey, 16, 24),
      Uint8List.sublistView(nodeKey, 24, 32),
    );
    final plain = kIsWeb || encrypted.length < 256 * 1024
        ? _decryptJob(args)
        : await compute(_decryptJob, args);
    if (plain == null) {
      throw const StorageException(ErrorCode.decryptionFailed);
    }
    return plain;
  }

  @override
  Future<void> delete(String path) => _serial(() async {
    final (folder, name) = _split(path);
    await _sync();
    final parent = await _folderHandle(folder, create: false);
    if (parent == null) return;
    for (final node in _childrenNamed(parent, name)) {
      await _deleteNode(node.handle);
    }
  });

  // ----------------------------------------------------- Публичные ссылки

  /// Открывает по ссылке папку с файлом [path] (если ещё не открыта) и
  /// возвращает адрес файла в ней.
  @override
  Future<String> publish(String path) => _serial(() async {
    var node = await _findFile(path);
    if (node == null) {
      await _sync(force: true);
      node = await _findFile(path);
    }
    final key = node == null ? null : _nodeKey(node);
    if (node == null || key == null) throw StorageNotFoundException(path);
    final folder = node.parent!;
    final shareKey = await _shareKey(folder);
    final share = MegaAes(shareKey);
    if (_exported.contains(folder)) {
      // Файл могло загрузить устройство, ещё не знавшее, что папка открыта:
      // ключ для читателей передаётся ещё раз (повтор безвреден).
      await _request({
        'a': 'k',
        'cr': [
          [folder],
          [node.handle],
          [0, 0, MegaCrypto.b64(share.encryptEcb(key))],
        ],
      }, path: path);
    } else {
      final keyed = [
        for (final n in _subtree(folder))
          if (_nodeKey(n) case final nodeKey?) (handle: n.handle, key: nodeKey),
      ];
      final keys = [
        [folder],
        [for (final n in keyed) n.handle],
        [
          for (var i = 0; i < keyed.length; i++) ...[
            0,
            i,
            MegaCrypto.b64(share.encryptEcb(keyed[i].key)),
          ],
        ],
      ];
      // Прежний формат с ok/ha (как в megajs) сервер теперь отвергает, а cr
      // внутри s2 молча пропускает — ключи для читателя уходят отдельно (k).
      await _request({
        'a': 's2',
        'n': folder,
        's': [
          {'u': 'EXP', 'r': 0},
        ],
        'cr': keys,
      }, path: path);
      await _request({'a': 'k', 'cr': keys}, path: path);
      _exported.add(folder);
    }
    var publicHandle = _publicHandles[folder];
    if (publicHandle == null) {
      final result = await _request({'a': 'l', 'n': folder}, path: path);
      if (result is! String) throw StorageException.request('MEGA', 'l');
      _publicHandles[folder] = publicHandle = result;
    }
    return MegaFolderLink(
      publicHandle: publicHandle,
      shareKey: shareKey,
      fileName: _nameOf(node)!,
    ).encode();
  });

  /// Закрывает ссылку на папку с файлом: перестают открываться все файлы
  /// папки (у доски так и задумано — закрывается вся доска).
  @override
  Future<void> unpublish(String path, String locator) => _serial(() async {
    final link = MegaFolderLink.parse(locator);
    if (link == null) return;
    await _sync(force: true);
    final folder =
        _publicHandles.entries
            .where((e) => e.value == link.publicHandle)
            .firstOrNull
            ?.key ??
        await _folderHandle(_split(path).$1, create: false);
    if (folder == null ||
        !_exported.contains(folder) && !_publicHandles.containsKey(folder)) {
      return;
    }
    for (final command in [
      {'a': 'l', 'n': folder, 'd': 1},
      {
        'a': 's2',
        'n': folder,
        's': [
          {'u': 'EXP', 'r': ''},
        ],
      },
    ]) {
      try {
        await _request(command, path: path);
      } on StorageNotFoundException {
        // Уже закрыто с другого устройства.
      }
    }
    _exported.remove(folder);
    _publicHandles.remove(folder);
  });

  /// Ключ нового узла [node] для читателей ссылок на папки над [parent]
  /// (`cr`); `null`, если таких ссылок нет.
  Future<List<Object>?> _keysForReaders(
    String parent,
    String node,
    Uint8List key,
  ) async {
    final shares = [
      for (final handle in _ancestors(parent))
        if (_exported.contains(handle)) handle,
    ];
    if (shares.isEmpty) return null;
    return [
      shares,
      [node],
      [
        for (var i = 0; i < shares.length; i++) ...[
          i,
          0,
          MegaCrypto.b64(MegaAes(await _shareKey(shares[i])).encryptEcb(key)),
        ],
      ],
    ];
  }

  Future<Uint8List> _shareKey(String folder) async => _shareKeys[folder] ??=
      await MegaFolderLink.deriveShareKey(_credentials.masterKey, folder);

  /// Папка [handle] и все папки над ней.
  Iterable<String> _ancestors(String handle) sync* {
    String? current = handle;
    final seen = <String>{};
    while (current != null && seen.add(current) && _nodes[current] != null) {
      yield current;
      current = _nodes[current]!.parent;
    }
  }

  /// Узел [handle] и всё, что в нём лежит.
  Iterable<_Node> _subtree(String handle) sync* {
    final node = _nodes[handle];
    if (node == null) return;
    yield node;
    for (final child in [...?_children[handle]]) {
      yield* _subtree(child);
    }
  }

  // ------------------------------------------------------------ Дерево

  Future<_Node?> _findFile(String path) async {
    final (folder, name) = _split(path);
    await _sync();
    final parent = await _folderHandle(folder, create: false);
    if (parent == null) return null;
    return _latestByName(parent)[name];
  }

  /// Дескриптор папки по пути от папки приложения; `null`, если её нет и
  /// [create] не задан.
  Future<String?> _folderHandle(String path, {required bool create}) async {
    await _sync();
    var current = _rootHandle;
    if (current == null) {
      throw StorageException.request('MEGA', 'no cloud drive root');
    }
    final parts = [
      appFolderName,
      ...path.split('/').where((p) => p.isNotEmpty),
    ];
    for (final name in parts) {
      final existing = _folderNamed(current!, name);
      if (existing != null) {
        current = existing;
      } else if (!create) {
        return null;
      } else {
        current = await _createFolder(current, name);
      }
    }
    return current;
  }

  String? _folderNamed(String parent, String name) {
    _Node? found;
    for (final handle in _children[parent] ?? const <String>{}) {
      final node = _nodes[handle]!;
      if (node.type != 1 || _nameOf(node) != name) continue;
      // Двойники (например, созданные двумя устройствами одновременно):
      // берём самую старую папку, чтобы все устройства выбрали одну.
      if (found == null ||
          node.timestamp < found.timestamp ||
          (node.timestamp == found.timestamp &&
              node.handle.compareTo(found.handle) < 0)) {
        found = node;
      }
    }
    return found?.handle;
  }

  Iterable<_Node> _childrenNamed(String parent, String name) => [
    for (final handle in _children[parent] ?? const <String>{})
      if (_nodes[handle] case final node?
          when node.type == 0 && _nameOf(node) == name)
        node,
  ];

  /// Файлы папки, по одному на имя — самый новый.
  Map<String, _Node> _latestByName(String parent) {
    final result = <String, _Node>{};
    for (final handle in _children[parent] ?? const <String>{}) {
      final node = _nodes[handle]!;
      if (node.type != 0) continue;
      final name = _nameOf(node);
      if (name == null) continue;
      final previous = result[name];
      if (previous == null || node.timestamp > previous.timestamp) {
        result[name] = node;
      }
    }
    return result;
  }

  Future<String> _createFolder(String parent, String name) async {
    final key = MegaCrypto.randomBytes(16);
    final result = await _request({
      'a': 'p',
      't': parent,
      'n': [
        {
          'h': 'xxxxxxxx',
          't': 1,
          'a': MegaCrypto.encryptAttributes({'n': name}, key),
          'k': MegaCrypto.b64(_master.encryptEcb(key)),
        },
      ],
    });
    final added = _addNodes(result);
    if (added.isEmpty) throw StorageException.request('MEGA', 'p');
    return added.first;
  }

  Future<void> _deleteNode(String handle) async {
    try {
      await _request({'a': 'd', 'n': handle});
    } on StorageNotFoundException {
      // Уже удалён другим устройством.
    }
    _removeNode(handle);
  }

  /// Имя узла (расшифровывается при первом обращении). `null` — чужой или
  /// повреждённый узел.
  String? _nameOf(_Node node) {
    if (node.decrypted) return node.name;
    node.decrypted = true;
    final key = _nodeKey(node);
    if (key == null || node.attributes == null) return null;
    final attributes = MegaCrypto.decryptAttributes(
      node.attributes!,
      MegaCrypto.fileAesKey(key),
    );
    final name = attributes?['n'];
    if (name is! String) return null;
    node
      ..key = key
      ..name = name;
    return name;
  }

  Uint8List? _nodeKey(_Node node) {
    final raw = node.rawKey;
    if (raw == null) return null;
    for (final part in raw.split('/')) {
      final separator = part.indexOf(':');
      if (separator < 0) continue;
      if (part.substring(0, separator) != _credentials.userHandle) continue;
      final Uint8List encrypted;
      try {
        encrypted = MegaCrypto.unb64(part.substring(separator + 1));
      } on FormatException {
        return null;
      }
      final expected = node.type == 0 ? 32 : 16;
      if (encrypted.length != expected) return null;
      return _master.decryptEcb(encrypted);
    }
    return null;
  }

  // ------------------------------------------------------- Синхронизация

  /// Загружает дерево или забирает изменения (не чаще [pollInterval]).
  Future<void> _sync({bool force = false}) {
    final running = _syncing;
    if (running != null) return running;
    final last = _lastSync;
    if (!force &&
        _sn != null &&
        last != null &&
        _clock().difference(last) < pollInterval) {
      return Future.value();
    }
    final future = (_sn == null ? _loadTree() : _pullChanges()).whenComplete(
      () => _syncing = null,
    );
    return _syncing = future;
  }

  Future<void> _loadTree() async {
    final result = await _request({'a': 'f', 'c': 1});
    if (result is! Map) throw StorageException.request('MEGA', 'f');
    _nodes.clear();
    _children.clear();
    _rootHandle = null;
    _addNodes(result);
    _exported
      ..clear()
      ..addAll([
        for (final share in result['s'] as List? ?? const [])
          if (share is Map && share['u'] == 'EXP' && share['h'] is String)
            share['h'] as String,
      ]);
    _publicHandles
      ..clear()
      ..addAll({
        for (final link in result['ph'] as List? ?? const [])
          if (link is Map && link['h'] is String && link['ph'] is String)
            link['h'] as String: link['ph'] as String,
      });
    _sn = result['sn'] as String?;
    _lastSync = _clock();
  }

  Future<void> _pullChanges() async {
    try {
      // Пакетов может быть несколько подряд; `w` — изменений больше нет.
      for (var i = 0; i < 20; i++) {
        final response = await _api.poll(_sn!);
        final actions = response['a'];
        if (actions is List) {
          for (final action in actions) {
            if (action is Map<String, Object?>) _apply(action);
          }
        }
        final sn = response['sn'];
        if (sn is String) _sn = sn;
        if (response.containsKey('w') || actions is! List || actions.isEmpty) {
          break;
        }
      }
      if (_sharingChanged) {
        // Ссылки открыли или закрыли (возможно, с другого устройства):
        // списки общих папок и ссылок есть только в полном дереве.
        _sharingChanged = false;
        await _loadTree();
        return;
      }
      _lastSync = _clock();
    } on MegaApiException catch (e) {
      if (e.code == MegaApiException.eSid) rethrow;
      // Журнал устарел или сломался — загрузим дерево заново.
      _sn = null;
      await _loadTree();
    }
  }

  void _apply(Map<String, Object?> action) {
    switch (action['a']) {
      case 't': // новые узлы (и перемещённые)
        final tree = action['t'];
        if (tree is Map) _addNodes(tree);
      case 'd': // удаление (или первая половина перемещения)
        final handle = action['n'];
        if (handle is String) _removeNode(handle);
      case 's' || 'ph': // общий ключ папки или публичная ссылка
        _sharingChanged = true;
      case 'u': // новые атрибуты (переименование)
        final node = _nodes[action['n']];
        final attributes = action['at'];
        if (node != null && attributes is String) {
          node
            ..attributes = attributes
            ..decrypted = false
            ..name = null;
        }
    }
  }

  /// Добавляет узлы из ответа (`{f: [...]}`) и возвращает их дескрипторы.
  List<String> _addNodes(Object? result) {
    final list = result is Map ? result['f'] : null;
    if (list is! List) return const [];
    final added = <String>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final handle = raw['h'];
      final type = raw['t'];
      if (handle is! String || type is! int) continue;
      final node = _Node(
        handle: handle,
        parent: raw['p'] as String?,
        type: type,
        size: (raw['s'] as num?)?.toInt() ?? 0,
        timestamp: (raw['ts'] as num?)?.toInt() ?? 0,
        attributes: raw['a'] as String?,
        rawKey: raw['k'] as String?,
      );
      final previous = _nodes[handle];
      if (previous?.parent != null) _children[previous!.parent]?.remove(handle);
      _nodes[handle] = node;
      if (node.parent != null) {
        (_children[node.parent!] ??= {}).add(handle);
      }
      if (type == 2) _rootHandle = handle;
      added.add(handle);
    }
    return added;
  }

  void _removeNode(String handle) {
    final node = _nodes.remove(handle);
    if (node == null) return;
    // Удалённая папка уносит и свою ссылку.
    _exported.remove(handle);
    _publicHandles.remove(handle);
    if (node.parent != null) _children[node.parent]?.remove(handle);
    for (final child in [...?_children.remove(handle)]) {
      _removeNode(child);
    }
  }

  // ------------------------------------------------------------ Служебное

  Future<Uint8List> _uploadPieces(String url, Uint8List data) async {
    var pieceStart = 0;
    var completion = Uint8List(0);
    final ends = MegaCrypto.chunkEnds(data.length);
    for (var i = 0; i < ends.length; i++) {
      final end = ends[i];
      final last = i == ends.length - 1;
      if (!last && end - pieceStart < _uploadPieceBytes) continue;
      try {
        completion = await _api.uploadChunk(
          url,
          pieceStart,
          Uint8List.sublistView(data, pieceStart, end),
        );
      } on MegaApiException catch (e) {
        throw megaStorageError(e.code);
      }
      pieceStart = end;
    }
    if (completion.isEmpty) {
      throw StorageException.request('MEGA', 'upload not completed');
    }
    return completion;
  }

  Future<Object?> _request(Map<String, Object?> command, {String? path}) async {
    try {
      return await _api.call(command);
    } on MegaApiException catch (e) {
      throw megaStorageError(e.code, path: path ?? '');
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  static (String, String) _split(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0
        ? ('', path)
        : (path.substring(0, slash), path.substring(slash + 1));
  }
}

class _Node {
  _Node({
    required this.handle,
    required this.parent,
    required this.type,
    required this.size,
    required this.timestamp,
    required this.attributes,
    required this.rawKey,
  });

  final String handle;
  final String? parent;

  /// 0 — файл, 1 — папка, 2 — корень диска, 3 — входящие, 4 — корзина.
  final int type;
  final int size;
  final int timestamp;
  String? attributes;
  final String? rawKey;

  bool decrypted = false;
  Uint8List? key;
  String? name;
}

// Функции верхнего уровня: их можно передать в compute().
({Uint8List data, Uint8List mac}) _encryptJob(
  (Uint8List, Uint8List, Uint8List) args,
) => MegaCrypto.encryptFile(args.$1, args.$2, args.$3);

Uint8List? _decryptJob((Uint8List, Uint8List, Uint8List, Uint8List) args) =>
    MegaCrypto.decryptFile(args.$1, args.$2, args.$3, args.$4);
