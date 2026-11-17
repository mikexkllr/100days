// Renders the app icon from Funki, the flame the app draws in code, so the
// icon and the mascot can never drift apart.
//
//   flutter test tool/app_icon_test.dart
//   ./tool/install_app_icon.sh
//
// Writes build/app_icon/: icon.png (1024², opaque: App Store and the iOS
// set), play.png (512², opaque: the Play listing) and foreground.png (432²,
// transparent: Android's adaptive icon, flame inside the safe zone) with
// background.png (432², the night behind it).
// Lives under tool/, not test/, so `flutter test` in CI does not run it.
// ICON_STAGE=<FlameStage name> renders another form of the flame.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:image/image.dart' as img;
import 'package:hundred_days/ui/mascot/flame_painter.dart';

final FlameStage _stage = FlameStage.values.byName(
  Platform.environment['ICON_STAGE'] ?? 'blaze',
);
const MascotMood _mood = MascotMood.happy;

/// The background of the icon: the app's night, lit from below.
void _paintNight(Canvas canvas, double s) {
  final Rect all = Rect.fromLTWH(0, 0, s, s);
  canvas.drawRect(all, Paint()..color = const Color(0xFF07080F));
  canvas.drawRect(
    all,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(s / 2, s * 0.78),
        s * 0.75,
        const <Color>[Color(0x66E25CFF), Color(0x228F7CFF), Color(0x00000000)],
        const <double>[0, 0.45, 1],
      ),
  );
}

void _paintFlame(Canvas canvas, double s, {required double fraction}) {
  final double side = s * fraction;
  canvas.save();
  canvas.translate((s - side) / 2, (s - side) / 2);
  FlamePainter(stage: _stage, mood: _mood, seconds: 1.15, blink: false)
      .paint(canvas, Size.square(side));
  canvas.restore();
}

Future<void> _write(
  String path,
  int pixels,
  void Function(Canvas, double) draw, {
  bool opaque = true,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  draw(canvas, pixels.toDouble());
  final ui.Image image = await recorder.endRecording().toImage(pixels, pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final Uint8List png = bytes!.buffer.asUint8List(
    bytes.offsetInBytes,
    math.max(0, bytes.lengthInBytes),
  );
  final File file = File(path)..createSync(recursive: true);
  // The App Store refuses an icon with an alpha channel, even a fully
  // opaque one: write those as RGB.
  file.writeAsBytesSync(
    opaque
        ? img.encodePng(img.decodePng(png)!.convert(numChannels: 3))
        : png,
  );
}

void main() {
  testWidgets('render the app icon', (WidgetTester tester) async {
    await tester.runAsync(() async {
      const String out = 'build/app_icon';
      await _write('$out/icon.png', 1024, (Canvas c, double s) {
        _paintNight(c, s);
        _paintFlame(c, s, fraction: 0.96);
      });
      await _write('$out/play.png', 512, (Canvas c, double s) {
        _paintNight(c, s);
        _paintFlame(c, s, fraction: 0.96);
      });
      // Adaptive icons show the middle 72 of 108 dp and may mask it to a
      // circle: keep the flame well inside.
      await _write('$out/foreground.png', 432, (Canvas c, double s) {
        _paintFlame(c, s, fraction: 0.62);
      }, opaque: false);
      await _write('$out/background.png', 432, _paintNight);
    });
  });
}
