import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The app's few sounds (assets/sounds, made by tool/make_sounds.py).
enum Sfx { ignite, tick, thud, gulp, poke, jackpot }

/// Plays [Sfx] — when the user has sounds on, and quietly in the
/// background of whatever else is playing: it mixes with music and follows
/// the silent switch.
///
/// A plain global, like haptics: the moments that sound (a check-in, a reel
/// landing, a poke) are spread over widgets that have no business knowing
/// about players. Silent until [AppSounds.start] runs — which only the app
/// does, so tests and the demo stay quiet.
class AppSounds {
  AppSounds._();

  static _Players? _players;

  /// Follows the setting; set by the app whenever it changes.
  static bool enabled = true;

  static Future<void> start() async {
    if (_players != null || kIsWeb) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
          respectSilence: true,
        ).build(),
      );
      _players = await _Players.load();
    } on Object catch (error) {
      debugPrint('Sounds unavailable: $error');
    }
  }

  static void play(Sfx sfx, {double volume = 1}) {
    final _Players? players = _players;
    if (!enabled || players == null) return;
    unawaited(players.play(sfx, volume).catchError((Object _) {}));
  }
}

class _Players {
  _Players(this._pools);

  final Map<Sfx, AudioPool> _pools;

  static Future<_Players> load() async {
    final Map<Sfx, AudioPool> pools = <Sfx, AudioPool>{};
    for (final Sfx sfx in Sfx.values) {
      pools[sfx] = await AudioPool.createFromAsset(
        path: 'sounds/${sfx.name}.wav',
        // Ticks come in quick runs; the rest one at a time.
        maxPlayers: sfx == Sfx.tick ? 4 : 2,
        playerMode: PlayerMode.lowLatency,
      );
    }
    return _Players(pools);
  }

  Future<void> play(Sfx sfx, double volume) async {
    await _pools[sfx]?.start(volume: volume);
  }
}
