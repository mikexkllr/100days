import 'dart:convert';

import '../identity/identity.dart';

/// A friend invitation, small enough to fit in a QR code.
///
/// There is no server to look anyone up on, so the invite itself carries
/// everything needed to find and verify the other person: their DID, a display
/// name, and the addresses they were last reachable at.
class Invite {
  const Invite({
    required this.did,
    required this.displayName,
    required this.avatarEmoji,
    this.addresses = const <String>[],
    this.issuedAt,
  });

  factory Invite.parse(String uri) {
    final parsed = Uri.parse(uri.trim());
    if (parsed.scheme != scheme || parsed.host != host) {
      throw FormatException('Not a 100days invite', uri);
    }
    final payload = parsed.queryParameters['d'];
    if (payload == null) {
      throw FormatException('Invite is missing its payload', uri);
    }
    final json = jsonDecode(utf8.decode(base64Url.decode(_pad(payload))))
        as Map<String, dynamic>;
    return Invite(
      did: json['did'] as String,
      displayName: json['name'] as String? ?? 'Anonym',
      avatarEmoji: json['emoji'] as String? ?? '🙂',
      addresses: (json['addr'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e as String)
          .toList(),
      issuedAt: json['ts'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((json['ts'] as num).toInt()),
    );
  }

  static const String scheme = 'hundreddays';
  static const String host = 'invite';

  final String did;
  final String displayName;
  final String avatarEmoji;
  final List<String> addresses;
  final DateTime? issuedAt;

  String get shortDid => Identity.shortDid(did);

  /// Sanity check before showing an invite as trustworthy: the DID must be a
  /// well-formed Ed25519 `did:key`, or nothing signed by it will verify later.
  bool get isWellFormed {
    try {
      Identity.publicKeyFromDid(did);
      return true;
    } on Object {
      return false;
    }
  }

  String toUri() {
    final payload = base64Url.encode(utf8.encode(jsonEncode(<String, dynamic>{
      'did': did,
      'name': displayName,
      'emoji': avatarEmoji,
      if (addresses.isNotEmpty) 'addr': addresses,
      'ts': (issuedAt ?? DateTime.now()).millisecondsSinceEpoch,
    })));
    return '$scheme://$host?d=${payload.replaceAll('=', '')}';
  }

  static String _pad(String input) {
    final remainder = input.length % 4;
    return remainder == 0 ? input : input + '=' * (4 - remainder);
  }
}
