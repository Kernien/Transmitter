import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../core/device/local_biometric_authenticator.dart';
import '../core/persistence/key_value_store.dart';

export '../core/device/local_biometric_authenticator.dart'
    show BiometricAuthenticator, NoBiometricAuthenticator;

/// Хранит проверочное значение ПИН-кода и состояние блокировки приложения.
///
/// Сам ПИН не сохраняется: используется PBKDF2 с отдельной случайной солью.
class AppLockController extends ChangeNotifier {
  AppLockController(
    this._store, {
    this.biometrics = const NoBiometricAuthenticator(),
    DateTime Function()? clock,
    Random? random,
    this.iterations = _defaultIterations,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure(),
       assert(iterations > 0);

  static const String _storeKey = 'app_lock_pin4';
  static const int pinLength = 4;
  static const int _defaultIterations = 100000;
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 1);
  static const Duration backgroundTimeout = Duration(minutes: 5);

  final SecureKeyValueStore _store;
  final BiometricAuthenticator biometrics;
  final DateTime Function() _clock;
  final Random _random;
  final int iterations;

  _PinRecord? _record;
  bool _corrupted = false;
  bool _locked = false;
  bool _biometricsAvailable = false;
  bool _automaticBiometricAttempted = false;
  DateTime? _backgroundedAt;

  bool get isEnabled => _record != null || _corrupted;
  bool get isLocked => _locked;
  bool get canRecover => _corrupted;
  bool get biometricsEnabled => _record?.biometricsEnabled ?? false;
  bool get biometricsAvailable => _biometricsAvailable;

  static bool isValidPin(String pin) =>
      pin.length == pinLength && RegExp(r'^[0-9]{4}$').hasMatch(pin);

  /// Разрешает автоматическую биометрическую попытку только один раз за блокировку.
  bool claimAutomaticBiometricAttempt() {
    if (_automaticBiometricAttempted) return false;
    _automaticBiometricAttempted = true;
    return true;
  }

  int get lockoutSecondsRemaining {
    final until = _record?.lockedUntil;
    if (until == null || !until.isAfter(_clock())) return 0;
    return until.difference(_clock()).inSeconds + 1;
  }

  Future<void> load() async {
    final raw = await _store.read(_storeKey);
    if (raw != null) {
      try {
        _record = _PinRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } on Object {
        // Повреждённую запись нельзя считать отсутствующей: блокируем доступ
        // и предлагаем удалить только локальные ключи.
        _corrupted = true;
      }
      _locked = true;
    }
    try {
      _biometricsAvailable = await biometrics.isAvailable;
    } on Object {
      _biometricsAvailable = false;
    }
    notifyListeners();
  }

  Future<void> setPin(String pin, {bool useBiometrics = false}) async {
    if (!isValidPin(pin)) throw ArgumentError.value(pin, 'pin');
    if (useBiometrics && !_biometricsAvailable) {
      throw StateError('Биометрия на устройстве недоступна');
    }

    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final hash = await _derive(pin, salt);
    final record = _PinRecord(
      salt: salt,
      hash: hash,
      biometricsEnabled: useBiometrics,
    );
    await _save(record);
    _record = record;
    _corrupted = false;
    _locked = false;
    notifyListeners();
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final record = _record;
    if (record == null) return;
    if (enabled && !_biometricsAvailable) {
      throw StateError('Биометрия на устройстве недоступна');
    }
    final updated = record.copyWith(biometricsEnabled: enabled);
    await _save(updated);
    _record = updated;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final record = _record;
    if (record == null || _corrupted) return false;
    if (lockoutSecondsRemaining > 0) return false;

    final candidate = await _derive(pin, record.salt);
    if (_constantTimeEquals(candidate, record.hash)) {
      final cleared = record.copyWith(failedAttempts: 0, clearLockout: true);
      await _save(cleared);
      _record = cleared;
      if (_locked) _automaticBiometricAttempted = false;
      _locked = false;
      notifyListeners();
      return true;
    }

    final attempts = record.failedAttempts + 1;
    final failed = attempts >= _maxFailedAttempts
        ? record.copyWith(
            failedAttempts: 0,
            lockedUntil: _clock().add(_lockoutDuration),
          )
        : record.copyWith(failedAttempts: attempts);
    await _save(failed);
    _record = failed;
    if (failed.lockedUntil != null) _locked = true;
    notifyListeners();
    return false;
  }

  Future<bool> unlockWithBiometrics({required String reason}) async {
    final record = _record;
    if (record == null ||
        !record.biometricsEnabled ||
        !_biometricsAvailable ||
        !_locked) {
      return false;
    }
    final authenticated = await biometrics.authenticate(reason: reason);
    if (!authenticated) return false;

    final cleared = record.copyWith(failedAttempts: 0, clearLockout: true);
    await _save(cleared);
    _record = cleared;
    _automaticBiometricAttempted = false;
    _locked = false;
    notifyListeners();
    return true;
  }

  /// Вызывается, когда приложение уходит в фон.
  void onBackground() {
    _backgroundedAt ??= _clock();
  }

  /// Блокирует приложение, если оно пробыло в фоне не меньше пяти минут.
  void onForeground() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (_record != null &&
        backgroundedAt != null &&
        _clock().difference(backgroundedAt) >= backgroundTimeout) {
      _locked = true;
      notifyListeners();
    }
  }

  /// Удаляет только настройку блокировки. Вызывается после подтверждённого
  /// восстановления, когда локальные ключи досок уже сброшены.
  Future<void> disable() async {
    await _store.delete(_storeKey);
    _record = null;
    _corrupted = false;
    _locked = false;
    _backgroundedAt = null;
    notifyListeners();
  }

  Future<void> _save(_PinRecord record) =>
      _store.write(_storeKey, jsonEncode(record.toJson()));

  Future<List<int>> _derive(String pin, List<int> salt) async =>
      (await Pbkdf2.hmacSha256(
        iterations: iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: pin, nonce: salt)).extractBytes();

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}

class _PinRecord {
  const _PinRecord({
    required this.salt,
    required this.hash,
    this.biometricsEnabled = false,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final List<int> salt;
  final List<int> hash;
  final bool biometricsEnabled;
  final int failedAttempts;
  final DateTime? lockedUntil;

  factory _PinRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('Версия ПИН-кода');
    final salt = base64Url.decode(json['salt'] as String);
    final hash = base64Url.decode(json['hash'] as String);
    final attempts = json['failedAttempts'] as int;
    final lockedUntil = json['lockedUntil'] as String?;
    if (salt.length != 16 || hash.length != 32 || attempts < 0) {
      throw const FormatException('Повреждена запись ПИН-кода');
    }
    return _PinRecord(
      salt: salt,
      hash: hash,
      biometricsEnabled: json['biometricsEnabled'] as bool? ?? false,
      failedAttempts: attempts,
      lockedUntil: lockedUntil == null ? null : DateTime.parse(lockedUntil),
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'salt': base64Url.encode(salt),
    'hash': base64Url.encode(hash),
    'biometricsEnabled': biometricsEnabled,
    'failedAttempts': failedAttempts,
    'lockedUntil': lockedUntil?.toUtc().toIso8601String(),
  };

  _PinRecord copyWith({
    bool? biometricsEnabled,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockout = false,
  }) => _PinRecord(
    salt: salt,
    hash: hash,
    biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: clearLockout ? null : lockedUntil ?? this.lockedUntil,
  );
}
