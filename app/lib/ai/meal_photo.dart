import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:image/image.dart' as img;

/// The longest side a meal photo is sent at: plenty to tell pasta from rice,
/// and a fraction of the tokens and bytes of a full camera image.
const int kMealPhotoMaxSide = 1024;

/// The longest side the picker hands over. A full 50-megapixel frame would
/// only be decoded to be scaled down again; asking for less also makes the
/// platform re-encode it, which turns a HEIC into something decodable.
const double kMealPhotoPickSide = 2048;

/// Why a meal photo could not be had, before the model saw it.
enum MealPhotoProblem {
  /// The camera, or the photos, are not allowed for the app.
  noPermission,

  /// The picker itself failed: no camera, a crashed activity.
  pickFailed,

  /// The file is not an image the app can read — a HEIC on many Androids.
  unreadable,
}

/// What a failed `pickImage` means for the user. The plugins report a
/// refused permission as a [PlatformException] with an `…_access_denied`
/// code.
MealPhotoProblem pickProblem(Object error) {
  if (error is PlatformException) {
    final String code = error.code.toLowerCase();
    if (code.contains('access_denied') || code.contains('permission')) {
      return MealPhotoProblem.noPermission;
    }
  }
  return MealPhotoProblem.pickFailed;
}

/// Prepares a camera or gallery image for the model, off the UI thread:
/// turned upright, scaled down, and re-encoded as a fresh JPEG — which is
/// what strips EXIF, GPS position and camera serial before anything leaves
/// the phone. Null when the bytes are not an image the app can decode, or
/// decoding them failed: never an exception, so the screen never waits on
/// one.
Future<LlmImage?> prepareMealPhoto(Uint8List original) async {
  try {
    return await compute(_prepare, original);
  } on Object {
    return null;
  }
}

LlmImage? _prepare(Uint8List original) {
  final img.Image? decoded = img.decodeImage(original);
  if (decoded == null) return null;
  // Honour the orientation the camera wrote, then forget the metadata.
  img.Image image = img.bakeOrientation(decoded);
  final int longest =
      image.width > image.height ? image.width : image.height;
  if (longest > kMealPhotoMaxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: kMealPhotoMaxSide)
        : img.copyResize(image, height: kMealPhotoMaxSide);
  }
  image.exif = img.ExifData();
  return LlmImage(
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 82)),
  );
}
