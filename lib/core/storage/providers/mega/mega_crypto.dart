import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'mega_aes.dart';

/// Криптография протокола MEGA (по открытому клиенту megajs и веб-клиенту
/// MEGA): ключи входа, атрибуты узлов, шифрование и MAC файлов.
///
/// Это шифрование самого MEGA. Содержимое Transmitter к этому моменту уже
/// зашифровано своим ключом базы.
abstract final class MegaCrypto {
  static final Random _random = Random.secure();

  /// base64url без «=», как в API MEGA. Декодер принимает и обычный base64.
  static String b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List unb64(String text) => base64Url.decode(
    base64Url.normalize(text.replaceAll('+', '-').replaceAll('/', '_')),
  );

  static Uint8List randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  // ---------------------------------------------------------------- Вход

  /// Ключ пароля и хеш для входа у аккаунтов версии 2 (с 2018 года):
  /// PBKDF2-HMAC-SHA512, 100 000 итераций. Первые 16 байт — ключ пароля,
  /// остальные 16 — то, что отправляется серверу.
  static Future<({Uint8List passwordKey, String userHash})> deriveV2(
    String password,
    Uint8List salt,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 100000,
      bits: 256,
    );
    final key = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = Uint8List.fromList(await key.extractBytes());
    return (
      passwordKey: Uint8List.sublistView(bytes, 0, 16),
      userHash: b64(Uint8List.sublistView(bytes, 16, 32)),
    );
  }

  /// Ключ пароля у старых аккаунтов (версия 1): 65 536 раундов AES.
  static Uint8List prepareKeyV1(Uint8List password) {
    var pkey = Uint8List.fromList(const [
      147, 196, 103, 227, 125, 176, 199, 164, //
      209, 190, 63, 129, 1, 82, 203, 86,
    ]);
    final ciphers = <MegaAes>[
      for (var j = 0; j < password.length; j += 16)
        MegaAes(_zeroPadded(password, j, 16)),
    ];
    for (var r = 0; r < 65536; r++) {
      for (final aes in ciphers) {
        aes.encryptBlock(pkey, 0, pkey, 0);
      }
    }
    return pkey;
  }

  /// Хеш почты для входа у аккаунтов версии 1.
  static String userHashV1(String email, Uint8List passwordKey) {
    final bytes = utf8.encode(email);
    final words = Uint32List(4);
    for (var i = 0; i < bytes.length; i += 4) {
      final chunk = _zeroPadded(bytes, i, 4);
      words[(i ~/ 4) & 3] ^=
          (chunk[0] << 24) | (chunk[1] << 16) | (chunk[2] << 8) | chunk[3];
    }
    final hash = Uint8List(16);
    for (var i = 0; i < 4; i++) {
      hash.buffer.asByteData().setUint32(i * 4, words[i]);
    }
    final aes = MegaAes(passwordKey);
    for (var i = 0; i < 16384; i++) {
      aes.encryptBlock(hash, 0, hash, 0);
    }
    return b64([...hash.sublist(0, 4), ...hash.sublist(8, 12)]);
  }

  /// Расшифровывает идентификатор сеанса: [csid] зашифрован RSA-ключом
  /// аккаунта, а закрытый ключ [privk] — мастер-ключом.
  static String decryptSessionId({
    required Uint8List csid,
    required Uint8List privk,
    required Uint8List masterKey,
  }) {
    final key = MegaAes(masterKey).decryptEcb(_padTo16(privk));
    var offset = 0;
    BigInt next(Uint8List data) {
      final (value, end) = _readMpi(data, offset);
      offset = end;
      return value;
    }

    final p = next(key);
    final q = next(key);
    final d = next(key);
    offset = 0;
    final c = next(csid);
    // Китайская теорема об остатках: быстрее, чем c^d mod pq.
    final xp = c.modPow(d % (p - BigInt.one), p);
    final xq = c.modPow(d % (q - BigInt.one), q);
    final h = ((xq - xp) * p.modInverse(q)) % q;
    final m = xp + h * p;
    final bytes = _bigIntBytes(m);
    if (bytes.length < 43) throw const FormatException('MEGA: bad session id');
    return b64(bytes.sublist(0, 43));
  }

  // ---------------------------------------------------------- Узлы и атрибуты

  /// Атрибуты узла («MEGA{json}», дополнено нулями) шифруются AES-CBC.
  static String encryptAttributes(
    Map<String, Object?> attributes,
    Uint8List key,
  ) {
    final text = utf8.encode('MEGA${jsonEncode(attributes)}');
    return b64(MegaAes(key).encryptCbc(_padTo16(text)));
  }

  /// `null`, если ключ не подходит.
  static Map<String, Object?>? decryptAttributes(
    String encrypted,
    Uint8List key,
  ) {
    final Uint8List plain;
    try {
      plain = MegaAes(key).decryptCbc(_padTo16(unb64(encrypted)));
    } on FormatException {
      return null;
    }
    var end = plain.indexOf(0);
    if (end < 0) end = plain.length;
    final String text;
    try {
      text = utf8.decode(Uint8List.sublistView(plain, 0, end));
    } on FormatException {
      return null;
    }
    if (!text.startsWith('MEGA{"')) return null;
    try {
      final json = jsonDecode(text.substring(4));
      return json is Map<String, Object?> ? json : null;
    } on FormatException {
      return null;
    }
  }

  /// Ключ AES файла из 32-байтного ключа узла: половины складываются XOR.
  static Uint8List fileAesKey(Uint8List nodeKey) {
    if (nodeKey.length == 16) return nodeKey;
    return Uint8List.fromList([
      for (var i = 0; i < 16; i++) nodeKey[i] ^ nodeKey[i + 16],
    ]);
  }

  /// 32-байтный ключ узла файла: ключ AES, nonce и MAC содержимого.
  static Uint8List packFileKey(
    Uint8List aesKey,
    Uint8List nonce,
    Uint8List mac,
  ) {
    final tail = Uint8List.fromList([...nonce, ...mac]);
    return Uint8List.fromList([
      for (var i = 0; i < 16; i++) aesKey[i] ^ tail[i],
      ...tail,
    ]);
  }

  // ----------------------------------------------------------- Содержимое

  /// Границы кусков MAC: 128 КБ, 256 КБ, … до 1 МБ, дальше по 1 МБ.
  /// Возвращает концы кусков; у пустого файла — один пустой кусок.
  static List<int> chunkEnds(int size) {
    final ends = <int>[];
    var position = 0;
    var step = 131072;
    while (position + step < size) {
      position += step;
      ends.add(position);
      if (step < 1048576) step += 131072;
    }
    ends.add(size);
    return ends;
  }

  /// Шифрует файл (AES-CTR) и считает MAC MEGA (8 байт).
  static ({Uint8List data, Uint8List mac}) encryptFile(
    Uint8List plain,
    Uint8List key,
    Uint8List nonce,
  ) {
    final out = Uint8List(plain.length);
    final mac = _ctrAndMac(plain, out, key, nonce, encrypting: true);
    return (data: out, mac: mac);
  }

  /// Расшифровывает файл. `null`, если MAC не совпал.
  static Uint8List? decryptFile(
    Uint8List encrypted,
    Uint8List key,
    Uint8List nonce,
    Uint8List expectedMac,
  ) {
    final out = Uint8List(encrypted.length);
    final mac = _ctrAndMac(encrypted, out, key, nonce, encrypting: false);
    var diff = 0;
    for (var i = 0; i < 8; i++) {
      diff |= mac[i] ^ expectedMac[i];
    }
    return diff == 0 ? out : null;
  }

  /// CTR-шифрование и MAC открытого текста за один проход.
  static Uint8List _ctrAndMac(
    Uint8List input,
    Uint8List output,
    Uint8List key,
    Uint8List nonce, {
    required bool encrypting,
  }) {
    final aes = MegaAes(key);
    final counter = Uint8List(16)..setRange(0, 8, nonce);
    final counterView = ByteData.sublistView(counter);
    final stream = Uint8List(16);
    final chunkMac = Uint8List(16);
    final fileMac = Uint8List(16);
    final plainBlock = Uint8List(16);
    var block = 0;
    var start = 0;
    for (final end in chunkEnds(input.length)) {
      chunkMac
        ..setRange(0, 8, nonce)
        ..setRange(8, 16, nonce);
      for (var i = start; i < end; i += 16) {
        final n = min(16, end - i);
        // Без сдвигов на 32: в вебе они обрезаются до 32 бит.
        counterView.setUint32(8, block ~/ 0x100000000);
        counterView.setUint32(12, block % 0x100000000);
        block++;
        aes.encryptBlock(counter, 0, stream, 0);
        for (var j = 0; j < n; j++) {
          final x = input[i + j];
          final y = x ^ stream[j];
          output[i + j] = y;
          plainBlock[j] = encrypting ? x : y;
        }
        for (var j = n; j < 16; j++) {
          plainBlock[j] = 0;
        }
        for (var j = 0; j < 16; j++) {
          chunkMac[j] ^= plainBlock[j];
        }
        aes.encryptBlock(chunkMac, 0, chunkMac, 0);
      }
      for (var j = 0; j < 16; j++) {
        fileMac[j] ^= chunkMac[j];
      }
      aes.encryptBlock(fileMac, 0, fileMac, 0);
      start = end;
    }
    return Uint8List.fromList([
      for (var j = 0; j < 4; j++) fileMac[j] ^ fileMac[j + 4],
      for (var j = 8; j < 12; j++) fileMac[j] ^ fileMac[j + 4],
    ]);
  }

  // -------------------------------------------------------------- Hashcash

  /// Ответ на «hashcash» — доказательство работы, которое MEGA иногда
  /// требует перед входом (заголовок `X-Hashcash`).
  static Future<String> solveHashcash(String challenge) async {
    final parts = challenge.split(':');
    if (parts.length < 4 || parts[0] != '1') {
      throw FormatException('MEGA: unknown hashcash "$challenge"');
    }
    final easiness = int.parse(parts[1]);
    final base = ((easiness & 63) << 1) + 1;
    final shifts = (easiness >> 6) * 7 + 3;
    final threshold = base << shifts;
    final token = unb64(parts[3]);
    const copies = 262144;
    final buffer = Uint8List(4 + copies * token.length);
    for (var i = 0; i < copies; i++) {
      buffer.setRange(4 + i * token.length, 4 + (i + 1) * token.length, token);
    }
    final sha256 = Sha256();
    while (true) {
      final hash = (await sha256.hash(buffer)).bytes;
      final value =
          (hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3];
      if (value <= threshold) {
        return '1:${parts[3]}:${b64(buffer.sublist(0, 4))}';
      }
      for (var j = 0; j < 4; j++) {
        buffer[j] = (buffer[j] + 1) & 0xff;
        if (buffer[j] != 0) break;
      }
    }
  }

  // ------------------------------------------------------------ Служебное

  static Uint8List _zeroPadded(List<int> data, int start, int length) {
    final out = Uint8List(length);
    final end = min(start + length, data.length);
    out.setRange(0, end - start, data, start);
    return out;
  }

  static Uint8List _padTo16(List<int> data) {
    final length = (data.length + 15) ~/ 16 * 16;
    return Uint8List(length)..setRange(0, data.length, data);
  }

  /// MPI: 2 байта — длина в битах, затем число big-endian.
  static (BigInt, int) _readMpi(Uint8List data, int offset) {
    if (offset + 2 > data.length) {
      throw const FormatException('MEGA: truncated key');
    }
    final bits = (data[offset] << 8) | data[offset + 1];
    final length = (bits + 7) >> 3;
    final end = offset + 2 + length;
    if (end > data.length) throw const FormatException('MEGA: truncated key');
    var value = BigInt.zero;
    for (var i = offset + 2; i < end; i++) {
      value = (value << 8) | BigInt.from(data[i]);
    }
    return (value, end);
  }

  static Uint8List _bigIntBytes(BigInt value) {
    final hex = value.toRadixString(16);
    final padded = hex.length.isOdd ? '0$hex' : hex;
    return Uint8List.fromList([
      for (var i = 0; i < padded.length; i += 2)
        int.parse(padded.substring(i, i + 2), radix: 16),
    ]);
  }
}
