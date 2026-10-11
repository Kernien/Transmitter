import '../key_value_store.dart';

SecureKeyValueStore createPlatformKeyValueStore({required String appId}) =>
    const FlutterSecureKeyValueStore();
