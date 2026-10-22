import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../errors/app_error.dart';
import '../../cloud_provider_id.dart';
import '../../cloud_storage.dart';
import '../../public_sharing.dart';
import 'mega_aes.dart';
import 'mega_api.dart';
import 'mega_crypto.dart';
import 'mega_links.dart';
import 'mega_session.dart';

/// Скачивание из открытой по ссылке папки MEGA без входа ([MegaFolderLink]).
///
/// Список папки (`f` от имени читателя ссылки) запоминается ненадолго:
/// опись доски перезаписывается новым узлом, поэтому её узел в списке
/// быстро устаревает.
class MegaPublicReader implements PublicFileReader {
  MegaPublicReader(
    this._client, {
    @visibleForTesting this.listingTtl = const Duration(seconds: 15),
    @visibleForTesting DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final http.Client _client;
  final Duration listingTtl;
  final DateTime Function() _clock;
  final Map<String, _Listing> _listings = {};

  @override
  CloudProviderId get provider => CloudProviderId.mega;

  @override
  Future<Uint8List> download(String locator) async {
    final link = MegaFolderLink.parse(locator);
    if (link == null) throw StorageNotFoundException(locator);
    final api = MegaApi(_client, folder: link.publicHandle);
    var listing = await _listing(api, link);
    var file = listing.files[link.fileName];
    if (file == null && !listing.isFresh(_clock())) {
      listing = await _listing(api, link, reload: true);
      file = listing.files[link.fileName];
    }
    if (file == null) throw StorageNotFoundException(locator);
    try {
      return await _downloadFile(api, file, locator);
    } on StorageNotFoundException {
      // Файл перезаписали после того, как мы получили список папки.
      listing = await _listing(api, link, reload: true);
      file = listing.files[link.fileName];
      if (file == null) rethrow;
      return _downloadFile(api, file, locator);
    }
  }

  Future<_Listing> _listing(
    MegaApi api,
    MegaFolderLink link, {
    bool reload = false,
  }) async {
    final cached = _listings[link.publicHandle];
    if (!reload && cached != null && cached.isFresh(_clock())) return cached;
    final Object? result;
    try {
      result = await api.call({'a': 'f', 'c': 1, 'ca': 1, 'r': 1});
    } on MegaApiException catch (e) {
      throw _error(e.code, link.encode());
    }
    if (result is! Map) throw StorageException.request('MEGA', 'f');
    final share = MegaAes(link.shareKey);
    final files = <String, ({String handle, Uint8List key, int ts})>{};
    for (final raw in result['f'] as List? ?? const []) {
      if (raw is! Map || raw['t'] != 0) continue;
      final handle = raw['h'];
      final attributes = raw['a'];
      final key = _key(raw['k'], share);
      if (handle is! String || attributes is! String || key == null) continue;
      final name = MegaCrypto.decryptAttributes(
        attributes,
        MegaCrypto.fileAesKey(key),
      )?['n'];
      if (name is! String) continue;
      final ts = (raw['ts'] as num?)?.toInt() ?? 0;
      // Во время перезаписи старый и новый узел есть одновременно.
      final previous = files[name];
      if (previous == null || ts > previous.ts) {
        files[name] = (handle: handle, key: key, ts: ts);
      }
    }
    return _listings[link.publicHandle] = _Listing(
      files,
      _clock().add(listingTtl),
    );
  }

  /// Ключ файла для читателя: «<папка>:<ключ, зашифрованный ключом папки>».
  static Uint8List? _key(Object? raw, MegaAes share) {
    if (raw is! String) return null;
    for (final part in raw.split('/')) {
      final separator = part.indexOf(':');
      if (separator < 0) continue;
      final Uint8List encrypted;
      try {
        encrypted = MegaCrypto.unb64(part.substring(separator + 1));
      } on FormatException {
        continue;
      }
      if (encrypted.length == 32) return share.decryptEcb(encrypted);
    }
    return null;
  }

  Future<Uint8List> _downloadFile(
    MegaApi api,
    ({String handle, Uint8List key, int ts}) file,
    String locator,
  ) async {
    final Object? info;
    try {
      info = await api.call({'a': 'g', 'g': 1, 'ssl': 2, 'n': file.handle});
    } on MegaApiException catch (e) {
      throw _error(e.code, locator);
    }
    if (info is! Map) throw StorageException.request('MEGA', 'g');
    final error = info['e'];
    if (error is int && error < 0) throw _error(error, locator);
    final url = info['g'];
    if (url is! String) throw StorageNotFoundException(locator);
    final encrypted = await api.downloadBytes(url);
    final args = (
      encrypted,
      MegaCrypto.fileAesKey(file.key),
      Uint8List.sublistView(file.key, 16, 24),
      Uint8List.sublistView(file.key, 24, 32),
    );
    final plain = kIsWeb || encrypted.length < 256 * 1024
        ? _decryptJob(args)
        : await compute(_decryptJob, args);
    if (plain == null) throw const StorageException(ErrorCode.decryptionFailed);
    return plain;
  }

  /// Ссылку закрыли или папку удалили — для читателя это «файла нет».
  static StorageException _error(int code, String locator) => switch (code) {
    MegaApiException.eNoEnt ||
    MegaApiException.eAccess ||
    MegaApiException.eExpired ||
    MegaApiException.eBlocked => StorageNotFoundException(locator),
    _ => megaStorageError(code, path: locator),
  };
}

class _Listing {
  _Listing(this.files, this._expires);

  final Map<String, ({String handle, Uint8List key, int ts})> files;
  final DateTime _expires;

  bool isFresh(DateTime now) => now.isBefore(_expires);
}

Uint8List? _decryptJob((Uint8List, Uint8List, Uint8List, Uint8List) args) =>
    MegaCrypto.decryptFile(args.$1, args.$2, args.$3, args.$4);
