import 'package:local_auth/local_auth.dart';

/// Проверка биометрии, доступной на этом устройстве.
abstract interface class BiometricAuthenticator {
  Future<bool> get isAvailable;

  Future<bool> authenticate({required String reason});
}

/// Биометрия недоступна на платформе или устройстве.
class NoBiometricAuthenticator implements BiometricAuthenticator {
  const NoBiometricAuthenticator();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

/// Системный запрос биометрии на Android.
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  const LocalAuthBiometricAuthenticator(this._authentication);

  final LocalAuthentication _authentication;

  @override
  Future<bool> get isAvailable async {
    try {
      if (!await _authentication.canCheckBiometrics) return false;
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}
