import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:webcrypto/webcrypto.dart'
    show AesGcmSecretKey, OperationError, fillRandomBytes;

import 'cipher.dart';

/// AES-256-GCM.
///
/// Поддерживает два формата:
/// - **v1** (небольшие записи, `.post`, `.note`, `settings.bin`, `.board`,
///   и файлы до [defaultChunkSize]):
///   `nonce (12 байт) | шифротекст | MAC (16 байт)`.
/// - **v2 (`TRMC\x02`)** (потоковое шифрование файлов и буферы больше
///   [defaultChunkSize]):
///   заголовок 24 байта (`"TRMC\x02\x00\x00\x00"` | `baseNonce` 12 байт |
///   `chunkSize` uint32 big-endian), за которым идут независимые куски
///   открытого текста до `chunkSize` байт, каждый зашифрован своим nonce
///   (производным от `baseNonce`, номера куска и признака последнего куска)
///   и снабжён 16-байтным MAC.
///
/// На устройствах — BoringSSL (webcrypto, аппаратный AES: сотни МБ/с), в
/// вебе — WebCrypto браузера.
class AesGcmCipher implements Cipher {
  AesGcmCipher(List<int> keyBytes, {this.chunkSize = defaultChunkSize})
    : _keyBytes = Uint8List.fromList(keyBytes) {
    if (keyBytes.length != keyLength) {
      throw ArgumentError('AES-256 key must be $keyLength bytes');
    }
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be positive');
    }
  }

  static const int keyLength = 32;

  /// С какого размера данные в памяти обрабатываются в отдельном потоке.
  static const int backgroundThreshold = 4 * 1024 * 1024;

  /// Размер одного куска открытого текста при потоковом шифровании (4 МБ).
  static const int defaultChunkSize = 4 * 1024 * 1024;

  /// Размер куска открытого текста (в тестах можно задать меньший).
  final int chunkSize;

  final Uint8List _keyBytes;

  static bool _inBackground(List<int> data) =>
      !kIsWeb && data.length >= backgroundThreshold;

  // Ключ импортируется при каждом вызове: это дёшево, а общий Future
  // нельзя делить между зонами (в тестах виджетов он зависает).
  Future<AesGcmSecretKey> get _secretKey =>
      AesGcmSecretKey.importRawKey(_keyBytes);

  @override
  int encryptedLength(int plaintextLength) {
    final chunks = plaintextLength <= 0
        ? 1
        : (plaintextLength + chunkSize - 1) ~/ chunkSize;
    return _v2HeaderLength + plaintextLength + chunks * _macLength;
  }

  @override
  Future<Uint8List> encrypt(List<int> plaintext) async {
    if (plaintext.length > chunkSize) {
      return _inBackground(plaintext)
          ? compute(_encryptV2Job, (_keyBytes, plaintext, chunkSize))
          : _encryptV2(await _secretKey, plaintext, chunkSize);
    }
    return _inBackground(plaintext)
        ? compute(_encryptJob, (_keyBytes, plaintext))
        : _encryptV1(await _secretKey, plaintext);
  }

  @override
  Future<Uint8List> decrypt(List<int> ciphertext) async =>
      _inBackground(ciphertext)
      ? compute(_decryptJob, (_keyBytes, ciphertext))
      : _decryptAny(await _secretKey, ciphertext);

  @override
  Stream<Uint8List> encryptStream(Stream<List<int>> plaintext) async* {
    final key = await _secretKey;
    final baseNonce = Uint8List(_nonceLength);
    fillRandomBytes(baseNonce);
    yield _buildV2Header(baseNonce, chunkSize);

    final pending = BytesBuilder(copy: false);
    Uint8List? readyChunk;
    var chunkIndex = 0;

    await for (final piece in plaintext) {
      if (piece.isEmpty) continue;
      pending.add(piece);
      while (pending.length >= chunkSize) {
        final full = pending.takeBytes();
        var offset = 0;
        while (full.length - offset >= chunkSize) {
          final slice = Uint8List.sublistView(full, offset, offset + chunkSize);
          offset += chunkSize;
          if (readyChunk != null) {
            yield await _sealChunk(
              key,
              readyChunk,
              baseNonce,
              chunkSize,
              chunkIndex++,
              isLast: false,
            );
          }
          readyChunk = slice;
        }
        if (offset < full.length) {
          pending.add(Uint8List.sublistView(full, offset));
        }
      }
    }

    final tail = pending.takeBytes();
    if (tail.isNotEmpty) {
      if (readyChunk != null) {
        yield await _sealChunk(
          key,
          readyChunk,
          baseNonce,
          chunkSize,
          chunkIndex++,
          isLast: false,
        );
      }
      yield await _sealChunk(
        key,
        tail,
        baseNonce,
        chunkSize,
        chunkIndex,
        isLast: true,
      );
    } else if (readyChunk != null) {
      yield await _sealChunk(
        key,
        readyChunk,
        baseNonce,
        chunkSize,
        chunkIndex,
        isLast: true,
      );
    } else {
      // Пустой входной поток — один пустой финальный кусок с тегом.
      yield await _sealChunk(
        key,
        Uint8List(0),
        baseNonce,
        chunkSize,
        0,
        isLast: true,
      );
    }
  }

  @override
  Stream<Uint8List> decryptStream(Stream<List<int>> ciphertext) async* {
    final key = await _secretKey;
    final buffer = _ByteQueue();
    final iterator = StreamIterator(ciphertext);
    try {
      while (buffer.length < _v2HeaderLength) {
        if (!await iterator.moveNext()) break;
        buffer.add(iterator.current);
      }
      if (!buffer.startsWith(_v2Magic)) {
        // Формат v1 (один блок): дочитываем до конца и расшифровываем.
        while (await iterator.moveNext()) {
          buffer.add(iterator.current);
        }
        yield await _decryptV1(key, buffer.takeAll());
        return;
      }

      final header = buffer.take(_v2HeaderLength);
      final baseNonce = Uint8List.sublistView(header, 8, 20);
      final streamChunkSize = ByteData.sublistView(header, 20, 24).getUint32(0);
      if (streamChunkSize == 0 || streamChunkSize > _maxAllowedChunkSize) {
        throw const DecryptionException('invalid v2 chunk size');
      }
      final encChunkMax = streamChunkSize + _macLength;
      var chunkIndex = 0;

      while (true) {
        // Держим в буфере чуть больше одного зашифрованного куска, чтобы
        // точно знать, последний ли это кусок в потоке.
        while (buffer.length <= encChunkMax) {
          if (!await iterator.moveNext()) break;
          buffer.add(iterator.current);
        }
        if (buffer.length == 0) {
          throw const DecryptionException('truncated v2 stream');
        }
        if (buffer.length > encChunkMax) {
          final encChunk = buffer.take(encChunkMax);
          yield await _openChunk(
            key,
            encChunk,
            baseNonce,
            streamChunkSize,
            chunkIndex++,
            isLast: false,
          );
        } else {
          final encChunk = buffer.takeAll();
          yield await _openChunk(
            key,
            encChunk,
            baseNonce,
            streamChunkSize,
            chunkIndex,
            isLast: true,
          );
          return;
        }
      }
    } finally {
      await iterator.cancel();
    }
  }
}

const int _nonceLength = 12;
const int _macLength = 16;
const int _v2HeaderLength = 24;
const int _maxAllowedChunkSize = 64 * 1024 * 1024;

/// 8-байтная сигнатура потокового формата v2: `"TRMC\x02\x00\x00\x00"`.
const List<int> _v2Magic = [0x54, 0x52, 0x4D, 0x43, 0x02, 0x00, 0x00, 0x00];

// Функции верхнего уровня: их можно передать в compute().
Future<Uint8List> _encryptJob((Uint8List, List<int>) args) async =>
    _encryptV1(await AesGcmSecretKey.importRawKey(args.$1), args.$2);

Future<Uint8List> _encryptV2Job((Uint8List, List<int>, int) args) async =>
    _encryptV2(await AesGcmSecretKey.importRawKey(args.$1), args.$2, args.$3);

Future<Uint8List> _decryptJob((Uint8List, List<int>) args) async =>
    _decryptAny(await AesGcmSecretKey.importRawKey(args.$1), args.$2);

Future<Uint8List> _encryptV1(AesGcmSecretKey key, List<int> plaintext) async {
  final nonce = Uint8List(_nonceLength);
  fillRandomBytes(nonce);
  // webcrypto возвращает шифротекст с MAC в конце — остаётся дописать nonce.
  final sealed = await key.encryptBytes(plaintext, nonce);
  return Uint8List(_nonceLength + sealed.length)
    ..setAll(0, nonce)
    ..setAll(_nonceLength, sealed);
}

Future<Uint8List> _encryptV2(
  AesGcmSecretKey key,
  List<int> plaintext,
  int chunkSize,
) async {
  final bytes = plaintext is Uint8List
      ? plaintext
      : Uint8List.fromList(plaintext);
  final baseNonce = Uint8List(_nonceLength);
  fillRandomBytes(baseNonce);
  final chunks = bytes.isEmpty ? 1 : (bytes.length + chunkSize - 1) ~/ chunkSize;
  final out = Uint8List(_v2HeaderLength + bytes.length + chunks * _macLength);
  out.setAll(0, _buildV2Header(baseNonce, chunkSize));

  var outOffset = _v2HeaderLength;
  for (var i = 0; i < chunks; i++) {
    final start = i * chunkSize;
    final end = min(start + chunkSize, bytes.length);
    final isLast = i == chunks - 1;
    final sealed = await _sealChunk(
      key,
      Uint8List.sublistView(bytes, start, end),
      baseNonce,
      chunkSize,
      i,
      isLast: isLast,
    );
    out.setAll(outOffset, sealed);
    outOffset += sealed.length;
  }
  return out;
}

Future<Uint8List> _decryptAny(AesGcmSecretKey key, List<int> ciphertext) {
  if (_hasV2Magic(ciphertext)) {
    return _decryptV2(key, ciphertext);
  }
  return _decryptV1(key, ciphertext);
}

Future<Uint8List> _decryptV1(AesGcmSecretKey key, List<int> ciphertext) async {
  if (ciphertext.length < _nonceLength + _macLength) {
    throw const DecryptionException('ciphertext too short');
  }
  final bytes = ciphertext is Uint8List
      ? ciphertext
      : Uint8List.fromList(ciphertext);
  try {
    return await key.decryptBytes(
      Uint8List.sublistView(bytes, _nonceLength),
      Uint8List.sublistView(bytes, 0, _nonceLength),
    );
  } on OperationError {
    throw const DecryptionException();
  }
}

Future<Uint8List> _decryptV2(AesGcmSecretKey key, List<int> ciphertext) async {
  if (ciphertext.length < _v2HeaderLength + _macLength) {
    throw const DecryptionException('v2 ciphertext too short');
  }
  final bytes = ciphertext is Uint8List
      ? ciphertext
      : Uint8List.fromList(ciphertext);
  final baseNonce = Uint8List.sublistView(bytes, 8, 20);
  final chunkSize = ByteData.sublistView(bytes, 20, 24).getUint32(0);
  if (chunkSize == 0 || chunkSize > _maxAllowedChunkSize) {
    throw const DecryptionException('invalid v2 chunk size');
  }
  final encChunkMax = chunkSize + _macLength;
  final out = BytesBuilder(copy: false);
  var offset = _v2HeaderLength;
  var chunkIndex = 0;
  while (offset < bytes.length) {
    final remaining = bytes.length - offset;
    final isLast = remaining <= encChunkMax;
    final take = isLast ? remaining : encChunkMax;
    final plain = await _openChunk(
      key,
      Uint8List.sublistView(bytes, offset, offset + take),
      baseNonce,
      chunkSize,
      chunkIndex++,
      isLast: isLast,
    );
    out.add(plain);
    offset += take;
  }
  return out.takeBytes();
}

bool _hasV2Magic(List<int> data) {
  if (data.length < _v2HeaderLength) return false;
  for (var i = 0; i < _v2Magic.length; i++) {
    if (data[i] != _v2Magic[i]) return false;
  }
  return true;
}

Uint8List _buildV2Header(Uint8List baseNonce, int chunkSize) {
  final header = Uint8List(_v2HeaderLength);
  header.setAll(0, _v2Magic);
  header.setAll(8, baseNonce);
  ByteData.sublistView(header, 20, 24).setUint32(0, chunkSize);
  return header;
}

/// Производный nonce куска: связывает `baseNonce`, `chunkSize`, порядковый
/// номер куска [chunkIndex] и признак последнего куска [isLast], поэтому
/// куски нельзя переставить, продублировать или оборвать поток без ошибки MAC.
Uint8List _deriveChunkNonce(
  Uint8List baseNonce,
  int chunkSize,
  int chunkIndex, {
  required bool isLast,
}) {
  final nonce = Uint8List.fromList(baseNonce);
  final view = ByteData.sublistView(nonce);
  view.setUint32(0, view.getUint32(0) ^ chunkSize);
  final hi = chunkIndex ~/ 0x1000000;
  final lo = chunkIndex % 0x1000000;
  view.setUint32(4, view.getUint32(4) ^ hi);
  final tail = (lo << 8) | (isLast ? 1 : 0);
  view.setUint32(8, view.getUint32(8) ^ tail);
  return nonce;
}

Future<Uint8List> _sealChunk(
  AesGcmSecretKey key,
  Uint8List plain,
  Uint8List baseNonce,
  int chunkSize,
  int chunkIndex, {
  required bool isLast,
}) => key.encryptBytes(
  plain,
  _deriveChunkNonce(baseNonce, chunkSize, chunkIndex, isLast: isLast),
);

Future<Uint8List> _openChunk(
  AesGcmSecretKey key,
  Uint8List encrypted,
  Uint8List baseNonce,
  int chunkSize,
  int chunkIndex, {
  required bool isLast,
}) async {
  if (encrypted.length < _macLength) {
    throw const DecryptionException('chunk too short');
  }
  try {
    return await key.decryptBytes(
      encrypted,
      _deriveChunkNonce(baseNonce, chunkSize, chunkIndex, isLast: isLast),
    );
  } on OperationError {
    throw const DecryptionException();
  }
}

/// Очередь байтовых кусков для потокового разбора без лишнего копирования.
class _ByteQueue {
  final List<Uint8List> _chunks = [];
  int _headOffset = 0;
  int _length = 0;

  int get length => _length;

  void add(List<int> bytes) {
    if (bytes.isEmpty) return;
    _chunks.add(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    _length += bytes.length;
  }

  bool startsWith(List<int> prefix) {
    if (_length < prefix.length) return false;
    var chunkIdx = 0;
    var offset = _headOffset;
    for (var i = 0; i < prefix.length; i++) {
      final chunk = _chunks[chunkIdx];
      if (chunk[offset] != prefix[i]) return false;
      offset++;
      if (offset == chunk.length) {
        chunkIdx++;
        offset = 0;
      }
    }
    return true;
  }

  Uint8List take(int count) {
    if (count == 0) return Uint8List(0);
    final first = _chunks.first;
    if (_headOffset == 0 && first.length == count) {
      _chunks.removeAt(0);
      _length -= count;
      return first;
    }
    if (first.length - _headOffset > count) {
      final view = Uint8List.sublistView(
        first,
        _headOffset,
        _headOffset + count,
      );
      _headOffset += count;
      _length -= count;
      return view;
    }
    final out = Uint8List(count);
    var written = 0;
    while (written < count) {
      final head = _chunks.first;
      final available = head.length - _headOffset;
      final n = min(count - written, available);
      out.setRange(written, written + n, head, _headOffset);
      written += n;
      _headOffset += n;
      _length -= n;
      if (_headOffset == head.length) {
        _chunks.removeAt(0);
        _headOffset = 0;
      }
    }
    return out;
  }

  Uint8List takeAll() => take(_length);
}
