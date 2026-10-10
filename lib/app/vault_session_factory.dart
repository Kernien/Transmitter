import '../core/crypto/aes_gcm_cipher.dart';
import '../core/crypto/vault_key_derivation.dart';
import '../core/storage/cloud_connection_service.dart';
import '../core/vault/vault_key.dart';
import '../data/encrypted_cloud_post_repository.dart';
import '../data/post_repository.dart';

/// Собирает [PostRepository] для выбранного ключа: выводит секреты,
/// берёт хранилище подключённого облака и настраивает шифрование.
class VaultSessionFactory {
  const VaultSessionFactory({
    required this._connections,
    required this._deviceName,
    this._derivation = const VaultKeyDerivation(),
  });

  final CloudConnectionService _connections;
  final String _deviceName;
  final VaultKeyDerivation _derivation;

  Future<PostRepository> open(VaultKey key) async {
    final secrets = await _derivation.derive(key.secret);
    return EncryptedCloudPostRepository(
      storage: _connections.storageFor(key.provider),
      vaultId: secrets.vaultId,
      cipher: AesGcmCipher(secrets.encryptionKey),
      deviceName: _deviceName,
    );
  }
}
