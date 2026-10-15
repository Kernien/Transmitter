import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Значения, получаемые из секрета ключа хранилища.
class VaultSecrets {
  const VaultSecrets({required this.vaultId, required this.encryptionKey});

  /// Публичный идентификатор базы — имя папки в облаке. По нему нельзя
  /// восстановить секрет или ключ шифрования.
  final String vaultId;

  /// Ключ AES-256 для шифрования постов и файлов.
  final Uint8List encryptionKey;
}

/// Получает [VaultSecrets] из секрета через HKDF-SHA256.
///
/// Из одного секрета детерминированно выводятся независимые значения, поэтому
/// все устройства с одинаковым ключом находят одну и ту же папку и могут
/// расшифровать её содержимое.
class VaultKeyDerivation {
  const VaultKeyDerivation();

  static final List<int> _salt = utf8.encode('transmitter.v1');

  Future<VaultSecrets> derive(List<int> masterSecret) async {
    final id = await _expand(masterSecret, 'vault-id', 16);
    final encryptionKey = await _expand(masterSecret, 'encryption-key', 32);
    return VaultSecrets(vaultId: _hex(id), encryptionKey: encryptionKey);
  }

  /// Зерно ключа подписи публичной доски (Ed25519). Одинаково на всех
  /// устройствах владельца; читателю передаётся только открытый ключ.
  Future<Uint8List> boardSigningSeed(List<int> masterSecret) =>
      _expand(masterSecret, 'board-signing-key', 32);

  Future<Uint8List> _expand(List<int> secret, String info, int length) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: length);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(secret),
      nonce: _salt,
      info: utf8.encode(info),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
