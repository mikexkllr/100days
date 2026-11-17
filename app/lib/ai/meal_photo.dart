import 'package:flutter/foundation.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:image/image.dart' as img;

/// The longest side a meal photo is sent at: plenty to tell pasta from rice,
/// and a fraction of the tokens and bytes of a full camera image.
const int kMealPhotoMaxSide = 1024;

/// Prepares a camera or gallery image for the model, off the UI thread:
/// turned upright, scaled down, and re-encoded as a fresh JPEG — which is
/// what strips EXIF, GPS position and camera serial before anything leaves
/// the phone. Null when the bytes are not an image.
Future<LlmImage?> prepareMealPhoto(Uint8List original) =>
    compute(_prepare, original);

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
