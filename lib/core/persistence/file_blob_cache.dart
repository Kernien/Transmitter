import 'dart:io';

import 'package:flutter/foundation.dart';

import 'blob_cache.dart';

/// Общее для всех областей кеша: папка-корень и лимит на сохранённые файлы.
class _CacheRoot {
  _CacheRoot(this.directory);

  final Directory directory;
  int limitBytes = defaultFileCacheLimit;
  Future<void>? _trimming;
  bool _trimAgain = false;

  /// Сохранённые файлы (вложения) во всех областях.
  Future<List<File>> attachmentFiles() async {
    if (!await directory.exists()) return [];
    return [
      await for (final entity in directory.list(recursive: true))
        if (entity is File && isAttachmentCacheKey(_name(entity))) entity,
    ];
  }

  /// Подрезает кеш до лимита: первыми уходят файлы, которые открывали
  /// давнее всего. Записи, комментарии и описи досок не трогаются.
  /// Файл открыли: идущий проход уборки мог взять старое время открытия —
  /// после него пройдём ещё раз.
  void touched() {
    if (_trimming != null) _trimAgain = true;
  }

  void scheduleTrim() {
    if (_trimming != null) {
      _trimAgain = true;
      return;
    }
    _trimming = _trimLoop().whenComplete(() => _trimming = null);
  }

  Future<void> _trimLoop() async {
    do {
      _trimAgain = false;
      try {
        await trim();
      } on FileSystemException {
        // Файл занят — попробуем при следующей записи.
      }
    } while (_trimAgain);
  }

  Future<void> trim() async {
    // Лимит и время открытия берём в начале прохода: если их поменяют во
    // время уборки, следующий проход (_trimAgain) увидит свежие данные.
    final limit = limitBytes;
    final files = [
      for (final file in await attachmentFiles())
        (file: file, stat: await file.stat()),
    ]..sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    var total = files.fold<int>(0, (sum, f) => sum + f.stat.size);
    for (final entry in files) {
      if (total <= limit) break;
      // Файл открыли, пока шла уборка, — он свежий, не трогаем.
      final now = await entry.file.stat();
      if (now.modified != entry.stat.modified) continue;
      await entry.file.delete();
      total -= entry.stat.size;
    }
  }

  static String _name(File file) => file.uri.pathSegments.last;
}

/// Кеш в папке на диске: ключ — имя файла. Корневой кеш ([FileBlobCache.new])
/// держит лимит на сохранённые файлы ([CacheStorage]); области ([scope]) —
/// подпапки для баз и досок с общим лимитом.
class FileBlobCache implements DeviceCache {
  FileBlobCache(Directory directory) : this._(directory, _CacheRoot(directory));

  FileBlobCache._(this.directory, this._root);

  final Directory directory;
  final _CacheRoot _root;
  bool _ready = false;

  File _file(String key) => File('${directory.path}/$key');

  @override
  Future<Uint8List?> read(String key) async {
    try {
      final file = _file(key);
      final bytes = await file.readAsBytes();
      if (isAttachmentCacheKey(key)) {
        _root.touched();
        // Отметка «открывали недавно» — такой файл уйдёт из кеша последним.
        try {
          await file.setLastModified(DateTime.now());
        } on FileSystemException {
          // Не страшно.
        }
      }
      return bytes;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String key, List<int> bytes) async {
    if (!_ready) {
      await directory.create(recursive: true);
      _ready = true;
    }
    // Через временный файл: прерванная запись не оставит обрезанный файл.
    final temp = _file('$key.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(_file(key).path);
    if (isAttachmentCacheKey(key)) _root.scheduleTrim();
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _file(key).delete();
    } on FileSystemException {
      // Уже нет.
    }
  }

  @override
  BlobCache scope(String name) =>
      FileBlobCache._(Directory('${directory.path}/$name'), _root);

  @override
  bool get isPersistent => true;

  /// Завершение фоновой уборки кеша (для тестов).
  @visibleForTesting
  Future<void> get idle async {
    while (_root._trimming != null) {
      await _root._trimming;
    }
  }

  @override
  int get limitBytes => _root.limitBytes;

  @override
  set limitBytes(int value) {
    _root.limitBytes = value;
    _root.scheduleTrim();
  }

  @override
  Future<int> usedBytes() async {
    if (!await _root.directory.exists()) return 0;
    var total = 0;
    await for (final entity in _root.directory.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  @override
  Future<void> clearFiles() async {
    for (final file in await _root.attachmentFiles()) {
      try {
        await file.delete();
      } on FileSystemException {
        // Занят — останется до следующей уборки.
      }
    }
  }
}
