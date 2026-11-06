import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../feed/event.dart';
import '../identity/identity.dart';

/// Seals events only their author can read.
///
/// Private things — body stats, the food diary, a habit the user keeps to
/// themselves — still go into the user's own signed feed, so the chain stays
/// complete and a restore from the recovery key brings them back. But they
/// go in as an opaque `private` event: ChaCha20-Poly1305 under a key derived
/// from the identity seed. Friends replicate the bytes (which also makes
/// them a backup) and can verify the signature, but cannot read a word.
///
/// What a friend *can* tell is that a private event exists and when it was
/// written. That is the honest limit of this scheme, and the docs say so.
class PrivateBox {
  PrivateBox._(this._key);

  final SecretKey _key;

  static final Cipher _cipher = Chacha20.poly1305Aead();

  /// Format version inside the sealed payload, so the scheme can change
  /// without guessing.
  static const int version = 1;

  static Future<PrivateBox> forIdentity(Identity identity) async {
    final seed = await identity.seedBytes;
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(seed),
      nonce: utf8.encode('hundred-days'),
      info: utf8.encode('private-events-v1'),
    );
    return PrivateBox._(key);
  }

  /// The payload of a `private` event carrying [type] and [payload].
  Future<Map<String, dynamic>> seal(
    String type,
    Map<String, dynamic> payload,
  ) async {
    final clear = utf8.encode(jsonEncode(<String, dynamic>{
      't': type,
      'p': payload,
    }));
    final box = await _cipher.encrypt(clear, secretKey: _key);
    return <String, dynamic>{
      'v': version,
      'n': base64Encode(box.nonce),
      'c': base64Encode(box.cipherText),
      'm': base64Encode(box.mac.bytes),
    };
  }

  /// The type and payload sealed in [sealed], or null if it is not ours,
  /// from a future version, or tampered with.
  Future<({String type, Map<String, dynamic> payload})?> open(
    Map<String, dynamic> sealed,
  ) async {
    try {
      if ((sealed['v'] as num?)?.toInt() != version) return null;
      final box = SecretBox(
        base64Decode(sealed['c'] as String),
        nonce: base64Decode(sealed['n'] as String),
        mac: Mac(base64Decode(sealed['m'] as String)),
      );
      final clear = await _cipher.decrypt(box, secretKey: _key);
      final decoded = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      return (
        type: decoded['t'] as String,
        payload: Map<String, dynamic>.from(decoded['p'] as Map),
      );
    } on Object {
      return null;
    }
  }

  /// [events] with every private event of ours replaced by what it carries,
  /// in place, so a projection folds them exactly like public ones.
  ///
  /// Author, sequence, timestamp, hash and signature stay those of the
  /// sealed event: the result is for folding, never for re-validation.
  Future<List<FeedEvent>> openAll(List<FeedEvent> events) async {
    final result = <FeedEvent>[];
    for (final event in events) {
      if (event.type != FeedEventType.private) {
        result.add(event);
        continue;
      }
      final opened = await open(event.payload);
      if (opened == null) continue;
      result.add(FeedEvent(
        author: event.author,
        seq: event.seq,
        prevHash: event.prevHash,
        timestamp: event.timestamp,
        type: opened.type,
        payload: opened.payload,
        hash: event.hash,
        signature: event.signature,
      ));
    }
    return result;
  }
}
