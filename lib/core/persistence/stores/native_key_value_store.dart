import 'dart:io';

import '../file_key_value_store.dart';
import '../key_value_store.dart';

/// На Linux — файл в домашней папке (см. [FileKeyValueStore]), на остальных
/// системах — системное защищённое хранилище.
SecureKeyValueStore createPlatformKeyValueStore({required String appId}) =>
    Platform.isLinux
    ? FileKeyValueStore.xdg(appId)
    : const FlutterSecureKeyValueStore();
