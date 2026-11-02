import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// What the app knows about the phone it runs on, for picking a model.
///
/// Memory is the number that matters: a language model has to sit in RAM
/// next to everything else the phone is doing, and a model that does not fit
/// gets the app killed in the background — or makes the whole phone crawl.
class DeviceProfile {
  const DeviceProfile({
    required this.model,
    required this.ramMb,
    required this.supportsLocalAi,
  });

  /// Used when detection fails (tests, an unknown platform): assume a
  /// modest phone rather than a flagship.
  static const DeviceProfile unknown = DeviceProfile(
    model: '',
    ramMb: null,
    supportsLocalAi: true,
  );

  /// "Pixel 8", "iPhone 15 Pro", "samsung SM-S921B". Never translated.
  final String model;

  /// Total physical memory, or null when the platform would not say.
  final int? ramMb;

  /// False on hardware the inference engine has no build for (32-bit-only
  /// Android phones).
  final bool supportsLocalAi;

  double? get ramGb => ramMb == null ? null : ramMb! / 1024;

  /// RAM is sold as "8 GB" but reported as 7.4 GiB after the kernel takes
  /// its share; round to the number on the box.
  int? get advertisedRamGb {
    final gb = ramGb;
    if (gb == null) return null;
    const List<int> sizes = <int>[2, 3, 4, 6, 8, 12, 16, 18, 24];
    for (final int size in sizes) {
      if (gb <= size * 1.02) return size;
    }
    return gb.ceil();
  }

  static Future<DeviceProfile> detect({DeviceInfoPlugin? plugin}) async {
    final info = plugin ?? DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        final abis = android.supported64BitAbis;
        final brand = android.manufacturer.trim();
        final model = android.model.trim();
        return DeviceProfile(
          model: model.toLowerCase().startsWith(brand.toLowerCase())
              ? model
              : '$brand $model'.trim(),
          ramMb: android.physicalRamSize > 0 ? android.physicalRamSize : null,
          supportsLocalAi:
              abis.contains('arm64-v8a') || abis.contains('x86_64'),
        );
      }
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        return DeviceProfile(
          model: ios.modelName.isNotEmpty ? ios.modelName : ios.model,
          ramMb: ios.physicalRamSize > 0 ? ios.physicalRamSize : null,
          supportsLocalAi: true,
        );
      }
    } on Object {
      // Fall through: a profile we cannot read is treated as unknown.
    }
    return unknown;
  }
}
