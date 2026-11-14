import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Pure-Dart cryptographic helpers (SHA-256, HMAC-SHA256, PBKDF2-HMAC-SHA256)
/// so offline builds and tests work without adding external packages.
class SecurityCrypto {
  SecurityCrypto._();

  static const String _schemePrefix = 'pbkdf2_sha256';
  static const int defaultIterations = 5000;
  static const int _saltByteLength = 16;
  static const int _digestByteLength = 32;

  static final List<int> _primes = _firstNPrimes(64);
  static final Uint32List _initialHash = _deriveFractionalRoots(8, 2);
  static final Uint32List _roundConstants = _deriveFractionalRoots(64, 3);

  static List<int> _firstNPrimes(int count) {
    final result = <int>[];
    var candidate = 2;
    while (result.length < count) {
      var isPrime = true;
      for (final p in result) {
        if (p * p > candidate) break;
        if (candidate % p == 0) {
          isPrime = false;
          break;
        }
      }
      if (isPrime) {
        result.add(candidate);
      }
      candidate++;
    }
    return result;
  }

  /// Derives the first 32 fractional bits of p^(1/degree) for the first [count] primes.
  static Uint32List _deriveFractionalRoots(int count, int degree) {
    final out = Uint32List(count);
    final mask32 = BigInt.from(0xffffffff);
    final shiftBits = 32 * degree;
    for (var i = 0; i < count; i++) {
      final scaled = BigInt.from(_primes[i]) << shiftBits;
      final root = _integerNthRoot(scaled, degree);
      out[i] = (root & mask32).toInt();
    }
    return out;
  }

  static BigInt _integerNthRoot(BigInt value, int degree) {
    final bitShift = ((value.bitLength + degree - 1) ~/ degree) + 1;
    var current = BigInt.one << bitShift;
    final k = BigInt.from(degree);
    final kMinusOne = BigInt.from(degree - 1);

    while (true) {
      final denominator = current.pow(degree - 1);
      final next = ((kMinusOne * current) + (value ~/ denominator)) ~/ k;
      if (next >= current) {
        return current;
      }
      current = next;
    }
  }

  static int _rotr32(int x, int shift) {
    final v = x & 0xffffffff;
    return ((v >>> shift) | (v << (32 - shift))) & 0xffffffff;
  }

  /// Computes a raw 32-byte SHA-256 digest.
  static Uint8List sha256Bytes(List<int> input) {
    final msgLen = input.length;
    final rem = (msgLen + 9) % 64;
    final totalLen = rem == 0 ? msgLen + 9 : msgLen + 9 + (64 - rem);
    final padded = Uint8List(totalLen);
    padded.setRange(0, msgLen, input);
    padded[msgLen] = 0x80;

    final bitLenHigh = (msgLen >> 29) & 0xffffffff;
    final bitLenLow = (msgLen << 3) & 0xffffffff;
    final bd = ByteData.sublistView(padded);
    bd.setUint32(totalLen - 8, bitLenHigh, Endian.big);
    bd.setUint32(totalLen - 4, bitLenLow, Endian.big);

    final state = Uint32List.fromList(_initialHash);
    final schedule = Uint32List(64);
    final k = _roundConstants;

    for (var offset = 0; offset < totalLen; offset += 64) {
      for (var i = 0; i < 16; i++) {
        schedule[i] = bd.getUint32(offset + (i * 4), Endian.big);
      }
      for (var i = 16; i < 64; i++) {
        final w15 = schedule[i - 15];
        final w2 = schedule[i - 2];
        final s0 = _rotr32(w15, 7) ^ _rotr32(w15, 18) ^ (w15 >>> 3);
        final s1 = _rotr32(w2, 17) ^ _rotr32(w2, 19) ^ (w2 >>> 10);
        schedule[i] =
            (schedule[i - 16] + s0 + schedule[i - 7] + s1) & 0xffffffff;
      }

      var a = state[0];
      var b = state[1];
      var c = state[2];
      var d = state[3];
      var e = state[4];
      var f = state[5];
      var g = state[6];
      var h = state[7];

      for (var i = 0; i < 64; i++) {
        final bigS1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
        final ch = ((e & f) ^ ((~e & 0xffffffff) & g)) & 0xffffffff;
        final t1 = (h + bigS1 + ch + k[i] + schedule[i]) & 0xffffffff;
        final bigS0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
        final maj = ((a & b) ^ (a & c) ^ (b & c)) & 0xffffffff;
        final t2 = (bigS0 + maj) & 0xffffffff;

        h = g;
        g = f;
        f = e;
        e = (d + t1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & 0xffffffff;
      }

      state[0] = (state[0] + a) & 0xffffffff;
      state[1] = (state[1] + b) & 0xffffffff;
      state[2] = (state[2] + c) & 0xffffffff;
      state[3] = (state[3] + d) & 0xffffffff;
      state[4] = (state[4] + e) & 0xffffffff;
      state[5] = (state[5] + f) & 0xffffffff;
      state[6] = (state[6] + g) & 0xffffffff;
      state[7] = (state[7] + h) & 0xffffffff;
    }

    final digest = Uint8List(_digestByteLength);
    final outView = ByteData.sublistView(digest);
    for (var i = 0; i < 8; i++) {
      outView.setUint32(i * 4, state[i], Endian.big);
    }
    return digest;
  }

  /// Lowercase hex encoding of SHA-256([input]).
  static String sha256Hex(List<int> input) => _bytesToHex(sha256Bytes(input));

  /// Computes HMAC-SHA256([key], [message]).
  static Uint8List hmacSha256Bytes(List<int> key, List<int> message) {
    const blockSize = 64;
    final keyBlock = Uint8List(blockSize);
    if (key.length > blockSize) {
      final hashedKey = sha256Bytes(key);
      keyBlock.setRange(0, hashedKey.length, hashedKey);
    } else {
      keyBlock.setRange(0, key.length, key);
    }

    final innerInput = Uint8List(blockSize + message.length);
    final outerKeyPad = Uint8List(blockSize + _digestByteLength);
    for (var i = 0; i < blockSize; i++) {
      innerInput[i] = keyBlock[i] ^ 0x36;
      outerKeyPad[i] = keyBlock[i] ^ 0x5c;
    }
    innerInput.setRange(blockSize, innerInput.length, message);

    final innerHash = sha256Bytes(innerInput);
    outerKeyPad.setRange(blockSize, outerKeyPad.length, innerHash);
    return sha256Bytes(outerKeyPad);
  }

  /// Derives a key using PBKDF2-HMAC-SHA256 (single 32-byte block).
  static Uint8List pbkdf2Sha256(
    List<int> secretBytes,
    List<int> saltBytes, {
    int iterations = defaultIterations,
  }) {
    if (iterations < 1) {
      throw ArgumentError.value(iterations, 'iterations', 'Must be >= 1');
    }
    final firstBlockMsg = Uint8List(saltBytes.length + 4)
      ..setRange(0, saltBytes.length, saltBytes);
    // INT(1) big-endian = 0x00000001
    firstBlockMsg[saltBytes.length + 3] = 1;

    var u = hmacSha256Bytes(secretBytes, firstBlockMsg);
    final acc = Uint8List.fromList(u);
    for (var iter = 1; iter < iterations; iter++) {
      u = hmacSha256Bytes(secretBytes, u);
      for (var j = 0; j < _digestByteLength; j++) {
        acc[j] ^= u[j];
      }
    }
    return acc;
  }

  static bool isHashed(String value) {
    return value.startsWith('$_schemePrefix\$');
  }

  /// Generates a random 16-byte salt and hashes [secret] via PBKDF2-HMAC-SHA256.
  static String hashSecret(
    String secret, {
    int iterations = defaultIterations,
    Uint8List? salt,
  }) {
    final saltBytes = salt ?? _randomBytes(_saltByteLength);
    final derived = pbkdf2Sha256(
      utf8.encode(secret),
      saltBytes,
      iterations: iterations,
    );
    return '$_schemePrefix\$$iterations\$${_bytesToHex(saltBytes)}\$${_bytesToHex(derived)}';
  }

  /// Verifies [secret] against an encoded PBKDF2 hash in constant time.
  static bool verifySecret(String secret, String encoded) {
    if (encoded.isEmpty) return false;
    final parts = encoded.split('\$');
    if (parts.length != 4 || parts[0] != _schemePrefix) {
      return false;
    }
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) {
      return false;
    }
    final salt = _hexToBytes(parts[2]);
    final expected = _hexToBytes(parts[3]);
    if (salt == null || expected == null || expected.length != _digestByteLength) {
      return false;
    }
    final actual = pbkdf2Sha256(
      utf8.encode(secret),
      salt,
      iterations: iterations,
    );
    return constantTimeEquals(actual, expected);
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return bytes;
  }

  static String _bytesToHex(List<int> bytes) {
    final buf = StringBuffer();
    for (final b in bytes) {
      buf.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  static Uint8List? _hexToBytes(String hex) {
    if (hex.length.isOdd || hex.isEmpty) return null;
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }
}
