import 'package:flutter/foundation.dart';

import '../storage/cloud_provider_id.dart';

/// Ключ читателя публичной доски: смотреть, копировать, скачивать, но не
/// менять.
///
/// В нём нет секрета базы — только адрес описи доски в облаке владельца
/// ([locator]), ключ расшифровки и открытый ключ подписи владельца. Поэтому
/// из ключа читателя нельзя получить права владельца, а без него ссылка в
/// облаке даёт только зашифрованные байты.
@immutable
class ReaderKey {
  ReaderKey({
    required this.provider,
    required this.label,
    required this.locator,
    required List<int> encryptionKey,
    required List<int> ownerPublicKey,
  }) : encryptionKey = Uint8List.fromList(encryptionKey),
       ownerPublicKey = Uint8List.fromList(ownerPublicKey) {
    if (encryptionKey.length != 32 || ownerPublicKey.length != 32) {
      throw ArgumentError('Invalid reader key');
    }
  }

  final CloudProviderId provider;

  /// Название доски, которое видит читатель.
  final String label;

  /// Адрес описи доски для `PublicFileReader` этого облака.
  final String locator;

  /// Ключ AES-256, которым зашифрованы опись и файлы.
  final Uint8List encryptionKey;

  /// Открытый ключ Ed25519 владельца для проверки подписи описи.
  final Uint8List ownerPublicKey;

  ReaderKey copyWith({String? label}) => ReaderKey(
    provider: provider,
    label: label ?? this.label,
    locator: locator,
    encryptionKey: encryptionKey,
    ownerPublicKey: ownerPublicKey,
  );

  /// Та же доска, даже если локальные названия различаются.
  bool sameBoardAs(ReaderKey other) =>
      provider == other.provider && locator == other.locator;

  @override
  bool operator ==(Object other) =>
      other is ReaderKey &&
      sameBoardAs(other) &&
      label == other.label &&
      listEquals(encryptionKey, other.encryptionKey) &&
      listEquals(ownerPublicKey, other.ownerPublicKey);

  @override
  int get hashCode => Object.hash(provider, locator, label);
}
