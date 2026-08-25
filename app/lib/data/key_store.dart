import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hundred_core/hundred_core.dart';

/// Where the identity seed lives.
abstract class KeyStore {
  Future<Identity?> read();

  Future<void> write(Identity identity);

  Future<void> clear();

  Future<Identity> readOrCreate() async {
    final existing = await read();
    if (existing != null) return existing;
    final created = await Identity.generate();
    await write(created);
    return created;
  }
}

/// Persists the 32-byte identity seed in the platform keystore.
///
/// The seed *is* the account — there is no server that can reset it — so it
/// goes in the Keychain / Android Keystore rather than in shared preferences,
/// and it is only ever handed back out through the explicit "Recovery-Key
/// anzeigen" flow.
class SecureKeyStore extends KeyStore {
  SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _seedKey = 'hundred_days_identity_seed_v1';

  static const AndroidOptions _androidOptions =
      AndroidOptions(encryptedSharedPreferences: true);

  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  @override
  Future<Identity?> read() async {
    final encoded = await _storage.read(
      key: _seedKey,
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
    if (encoded == null) return null;
    return Identity.fromSeed(base64Decode(encoded));
  }

  @override
  Future<void> write(Identity identity) async {
    await _storage.write(
      key: _seedKey,
      value: base64Encode(await identity.seedBytes),
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  @override
  Future<void> clear() => _storage.delete(
        key: _seedKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
}

/// Stand-in for tests and previews, where no platform keystore exists.
class InMemoryKeyStore extends KeyStore {
  InMemoryKeyStore([this._identity]);

  Identity? _identity;

  @override
  Future<Identity?> read() async => _identity;

  @override
  Future<void> write(Identity identity) async => _identity = identity;

  @override
  Future<void> clear() async => _identity = null;
}
