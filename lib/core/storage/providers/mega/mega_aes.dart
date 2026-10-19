import 'dart:typed_data';

/// AES-128 для протокола MEGA: одиночные блоки, ECB, CBC с нулевым IV.
///
/// MEGA шифрует ключи и атрибуты по одному блоку (ECB), а MAC файла — это
/// цепочка шифрований отдельных блоков. Пакет cryptography даёт только
/// асинхронные режимы целиком, поэтому здесь своя быстрая синхронная
/// реализация на таблицах (FIPS-197).
class MegaAes {
  MegaAes(Uint8List key) : _enc = _expandKey(key) {
    _dec = _decryptionKeys(_enc);
  }

  final Uint32List _enc;
  late final Uint32List _dec;

  /// Шифрует 16 байт [src] со смещения [srcOffset] в [dst] (можно в тот же
  /// массив).
  void encryptBlock(
    Uint8List src,
    int srcOffset,
    Uint8List dst,
    int dstOffset,
  ) {
    final rk = _enc;
    var s0 = _read(src, srcOffset) ^ rk[0];
    var s1 = _read(src, srcOffset + 4) ^ rk[1];
    var s2 = _read(src, srcOffset + 8) ^ rk[2];
    var s3 = _read(src, srcOffset + 12) ^ rk[3];
    for (var r = 1; r < 10; r++) {
      final k = r * 4;
      final t0 =
          _te0[s0 >> 24] ^
          _te1[(s1 >> 16) & 0xff] ^
          _te2[(s2 >> 8) & 0xff] ^
          _te3[s3 & 0xff] ^
          rk[k];
      final t1 =
          _te0[s1 >> 24] ^
          _te1[(s2 >> 16) & 0xff] ^
          _te2[(s3 >> 8) & 0xff] ^
          _te3[s0 & 0xff] ^
          rk[k + 1];
      final t2 =
          _te0[s2 >> 24] ^
          _te1[(s3 >> 16) & 0xff] ^
          _te2[(s0 >> 8) & 0xff] ^
          _te3[s1 & 0xff] ^
          rk[k + 2];
      final t3 =
          _te0[s3 >> 24] ^
          _te1[(s0 >> 16) & 0xff] ^
          _te2[(s1 >> 8) & 0xff] ^
          _te3[s2 & 0xff] ^
          rk[k + 3];
      s0 = t0;
      s1 = t1;
      s2 = t2;
      s3 = t3;
    }
    _write(dst, dstOffset, _lastEnc(s0, s1, s2, s3) ^ rk[40]);
    _write(dst, dstOffset + 4, _lastEnc(s1, s2, s3, s0) ^ rk[41]);
    _write(dst, dstOffset + 8, _lastEnc(s2, s3, s0, s1) ^ rk[42]);
    _write(dst, dstOffset + 12, _lastEnc(s3, s0, s1, s2) ^ rk[43]);
  }

  void decryptBlock(
    Uint8List src,
    int srcOffset,
    Uint8List dst,
    int dstOffset,
  ) {
    final rk = _dec;
    var s0 = _read(src, srcOffset) ^ rk[0];
    var s1 = _read(src, srcOffset + 4) ^ rk[1];
    var s2 = _read(src, srcOffset + 8) ^ rk[2];
    var s3 = _read(src, srcOffset + 12) ^ rk[3];
    for (var r = 1; r < 10; r++) {
      final k = r * 4;
      final t0 =
          _td0[s0 >> 24] ^
          _td1[(s3 >> 16) & 0xff] ^
          _td2[(s2 >> 8) & 0xff] ^
          _td3[s1 & 0xff] ^
          rk[k];
      final t1 =
          _td0[s1 >> 24] ^
          _td1[(s0 >> 16) & 0xff] ^
          _td2[(s3 >> 8) & 0xff] ^
          _td3[s2 & 0xff] ^
          rk[k + 1];
      final t2 =
          _td0[s2 >> 24] ^
          _td1[(s1 >> 16) & 0xff] ^
          _td2[(s0 >> 8) & 0xff] ^
          _td3[s3 & 0xff] ^
          rk[k + 2];
      final t3 =
          _td0[s3 >> 24] ^
          _td1[(s2 >> 16) & 0xff] ^
          _td2[(s1 >> 8) & 0xff] ^
          _td3[s0 & 0xff] ^
          rk[k + 3];
      s0 = t0;
      s1 = t1;
      s2 = t2;
      s3 = t3;
    }
    _write(dst, dstOffset, _lastDec(s0, s3, s2, s1) ^ rk[40]);
    _write(dst, dstOffset + 4, _lastDec(s1, s0, s3, s2) ^ rk[41]);
    _write(dst, dstOffset + 8, _lastDec(s2, s1, s0, s3) ^ rk[42]);
    _write(dst, dstOffset + 12, _lastDec(s3, s2, s1, s0) ^ rk[43]);
  }

  /// ECB: каждый блок отдельно. Длина — кратна 16.
  Uint8List encryptEcb(Uint8List data) {
    _checkBlocks(data);
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i += 16) {
      encryptBlock(data, i, out, i);
    }
    return out;
  }

  Uint8List decryptEcb(Uint8List data) {
    _checkBlocks(data);
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i += 16) {
      decryptBlock(data, i, out, i);
    }
    return out;
  }

  /// CBC с нулевым IV и без дополнения — так MEGA шифрует атрибуты.
  Uint8List encryptCbc(Uint8List data) {
    _checkBlocks(data);
    final out = Uint8List(data.length);
    final block = Uint8List(16);
    for (var i = 0; i < data.length; i += 16) {
      for (var j = 0; j < 16; j++) {
        block[j] ^= data[i + j];
      }
      encryptBlock(block, 0, block, 0);
      out.setRange(i, i + 16, block);
    }
    return out;
  }

  Uint8List decryptCbc(Uint8List data) {
    _checkBlocks(data);
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i += 16) {
      decryptBlock(data, i, out, i);
      if (i > 0) {
        for (var j = 0; j < 16; j++) {
          out[i + j] ^= data[i - 16 + j];
        }
      }
    }
    return out;
  }

  static void _checkBlocks(Uint8List data) {
    if (data.length % 16 != 0) {
      throw ArgumentError('AES: length ${data.length} is not a multiple of 16');
    }
  }

  static int _read(Uint8List b, int o) =>
      (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

  static void _write(Uint8List b, int o, int v) {
    b[o] = (v >> 24) & 0xff;
    b[o + 1] = (v >> 16) & 0xff;
    b[o + 2] = (v >> 8) & 0xff;
    b[o + 3] = v & 0xff;
  }

  static int _lastEnc(int a, int b, int c, int d) =>
      (_sbox[a >> 24] << 24) |
      (_sbox[(b >> 16) & 0xff] << 16) |
      (_sbox[(c >> 8) & 0xff] << 8) |
      _sbox[d & 0xff];

  static int _lastDec(int a, int b, int c, int d) =>
      (_inv[a >> 24] << 24) |
      (_inv[(b >> 16) & 0xff] << 16) |
      (_inv[(c >> 8) & 0xff] << 8) |
      _inv[d & 0xff];

  static Uint32List _expandKey(Uint8List key) {
    if (key.length != 16) {
      throw ArgumentError('AES-128 needs a 16-byte key, got ${key.length}');
    }
    final w = Uint32List(44);
    for (var i = 0; i < 4; i++) {
      w[i] = _read(key, i * 4);
    }
    var rcon = 1;
    for (var i = 4; i < 44; i++) {
      var t = w[i - 1];
      if (i % 4 == 0) {
        // RotWord, SubWord, Rcon.
        t =
            (_sbox[(t >> 16) & 0xff] << 24) |
            (_sbox[(t >> 8) & 0xff] << 16) |
            (_sbox[t & 0xff] << 8) |
            _sbox[t >> 24];
        t ^= rcon << 24;
        rcon = _xtime(rcon);
      }
      w[i] = w[i - 4] ^ t;
    }
    return w;
  }

  /// Ключи для «эквивалентного обратного шифра»: в обратном порядке, к
  /// средним раундам применено InvMixColumns.
  static Uint32List _decryptionKeys(Uint32List enc) {
    final dec = Uint32List(44);
    for (var r = 0; r <= 10; r++) {
      for (var j = 0; j < 4; j++) {
        var w = enc[(10 - r) * 4 + j];
        if (r > 0 && r < 10) {
          w =
              _td0[_sbox[w >> 24]] ^
              _td1[_sbox[(w >> 16) & 0xff]] ^
              _td2[_sbox[(w >> 8) & 0xff]] ^
              _td3[_sbox[w & 0xff]];
        }
        dec[r * 4 + j] = w;
      }
    }
    return dec;
  }

  // Таблицы строятся один раз при первом обращении.
  static final Uint8List _sbox = _tables.sbox;
  static final Uint8List _inv = _tables.inv;
  static final Uint32List _te0 = _tables.te[0];
  static final Uint32List _te1 = _tables.te[1];
  static final Uint32List _te2 = _tables.te[2];
  static final Uint32List _te3 = _tables.te[3];
  static final Uint32List _td0 = _tables.td[0];
  static final Uint32List _td1 = _tables.td[1];
  static final Uint32List _td2 = _tables.td[2];
  static final Uint32List _td3 = _tables.td[3];

  static final _AesTables _tables = _AesTables();

  static int _xtime(int a) => ((a << 1) ^ ((a & 0x80) != 0 ? 0x1b : 0)) & 0xff;
}

class _AesTables {
  _AesTables() {
    // S-блок: обратный элемент в GF(2^8) и аффинное преобразование.
    var p = 1, q = 1;
    do {
      p = (p ^ (p << 1) ^ ((p & 0x80) != 0 ? 0x1b : 0)) & 0xff;
      q ^= q << 1;
      q ^= q << 2;
      q ^= q << 4;
      q &= 0xff;
      if ((q & 0x80) != 0) q ^= 0x09;
      final x = q ^ _rotl8(q, 1) ^ _rotl8(q, 2) ^ _rotl8(q, 3) ^ _rotl8(q, 4);
      sbox[p] = (x ^ 0x63) & 0xff;
    } while (p != 1);
    sbox[0] = 0x63;
    for (var i = 0; i < 256; i++) {
      inv[sbox[i]] = i;
    }
    for (var i = 0; i < 256; i++) {
      final s = sbox[i];
      final e = (_mul(s, 2) << 24) | (s << 16) | (s << 8) | _mul(s, 3);
      final si = inv[i];
      final d =
          (_mul(si, 14) << 24) |
          (_mul(si, 9) << 16) |
          (_mul(si, 13) << 8) |
          _mul(si, 11);
      for (var t = 0; t < 4; t++) {
        te[t][i] = _ror(e, 8 * t);
        td[t][i] = _ror(d, 8 * t);
      }
    }
  }

  final sbox = Uint8List(256);
  final inv = Uint8List(256);
  final te = List.generate(4, (_) => Uint32List(256));
  final td = List.generate(4, (_) => Uint32List(256));

  static int _rotl8(int x, int s) => ((x << s) | (x >> (8 - s))) & 0xff;

  static int _ror(int x, int s) =>
      s == 0 ? x : ((x >> s) | (x << (32 - s))) & 0xffffffff;

  static int _mul(int a, int b) {
    var r = 0;
    while (b != 0) {
      if ((b & 1) != 0) r ^= a;
      a = ((a << 1) ^ ((a & 0x80) != 0 ? 0x1b : 0)) & 0xff;
      b >>= 1;
    }
    return r;
  }
}
