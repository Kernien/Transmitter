import 'dart:typed_data';

import 'cloud_provider_id.dart';

/// Открытие файлов облака по ссылке — для читателей публичных досок, у
/// которых нет доступа к облаку владельца. Реализуют хранилища облаков,
/// которые это умеют.
abstract interface class PublicSharing {
  /// Открывает файл [path] всем, у кого есть ссылка, и возвращает адрес
  /// (локатор) для [PublicFileReader] этого облака. Если файл уже открыт,
  /// возвращает прежний адрес.
  Future<String> publish(String path);

  /// Закрывает доступ по ссылке. Если доступа уже нет, ничего не делает.
  Future<void> unpublish(String path, String locator);
}

/// Чтение открытых по ссылке файлов без входа в облако.
abstract interface class PublicFileReader {
  CloudProviderId get provider;

  /// Бросает `StorageNotFoundException`, если файла нет или доступ закрыт.
  Future<Uint8List> download(String locator);
}
