import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../theme/fire.dart';
import '../../theme/theme.dart';
import '../mascot/flame_painter.dart';

/// "Brag about it" as a picture: Funki in his current form, the streak and
/// the day, on the night sky — the same painter as in the app, drawn into
/// an image so it travels to any chat.
Future<Uint8List> renderShareCard({
  required FlameStage stage,
  required int streak,
  required String streakLabel,
  required String dayLine,
  int width = 1080,
  int height = 1350,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Size size = Size(width.toDouble(), height.toDouble());
  final Fire fire = Fire.of(stage);

  // The night, lit from where Funki stands.
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.25),
        radius: 1.1,
        colors: <Color>[
          Color.lerp(AppColors.ink, fire.main, 0.35)!,
          AppColors.ink,
          AppColors.inkDeep,
        ],
      ).createShader(Offset.zero & size),
  );
  // A few stars, fixed so every card of the same streak looks the same.
  final math.Random random = math.Random(streak);
  final Paint star = Paint()..color = Colors.white.withValues(alpha: 0.7);
  for (int i = 0; i < 70; i++) {
    canvas.drawCircle(
      Offset(random.nextDouble() * size.width,
          random.nextDouble() * size.height * 0.75),
      random.nextDouble() * 2.6 + 0.6,
      star,
    );
  }

  final double flame = size.width * 0.62;
  canvas.save();
  canvas.translate((size.width - flame) / 2, size.height * 0.08);
  FlamePainter(
    stage: stage,
    mood: MascotMood.hyped,
    seconds: 1.2,
    blink: false,
  ).paint(canvas, Size.square(flame));
  canvas.restore();

  void text(String value, double y, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.86);
    painter.paint(canvas, Offset((size.width - painter.width) / 2, y));
  }

  text(
    '$streak',
    size.height * 0.56,
    TextStyle(
      fontFamily: kDisplayFont,
      fontWeight: FontWeight.w800,
      fontSize: 230,
      height: 1,
      foreground: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[fire.light, fire.main],
        ).createShader(Rect.fromLTWH(0, size.height * 0.56, size.width, 240)),
    ),
  );
  text(
    streakLabel.toUpperCase(),
    size.height * 0.75,
    const TextStyle(
      fontFamily: kTextFont,
      fontWeight: FontWeight.w800,
      fontSize: 44,
      letterSpacing: 6,
      color: Colors.white,
    ),
  );
  text(
    dayLine,
    size.height * 0.82,
    TextStyle(
      fontFamily: kTextFont,
      fontWeight: FontWeight.w600,
      fontSize: 40,
      color: Colors.white.withValues(alpha: 0.7),
    ),
  );
  text(
    '100 Days',
    size.height * 0.92,
    TextStyle(
      fontFamily: kDisplayFont,
      fontWeight: FontWeight.w700,
      fontSize: 34,
      color: Colors.white.withValues(alpha: 0.45),
    ),
  );

  final ui.Image image =
      await recorder.endRecording().toImage(width, height);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Shares the streak as a picture with [text] alongside; falls back to the
/// text alone where pictures cannot be written (tests, no storage).
Future<void> shareStreak(
  BuildContext context, {
  required FlameStage stage,
  required int streak,
  required int dayNumber,
  required String text,
}) async {
  final AppLocalizations l10n = context.l10n;
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  final Rect? origin =
      box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  try {
    final Uint8List png = await renderShareCard(
      stage: stage,
      streak: streak,
      streakLabel: l10n.shareCardStreak(streak),
      dayLine: l10n.shareCardDay(dayNumber),
    );
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/100days-streak-$streak.png');
    await file.writeAsBytes(png, flush: true);
    await Share.shareXFiles(
      <XFile>[XFile(file.path, mimeType: 'image/png')],
      text: text,
      sharePositionOrigin: origin,
    );
  } on Object {
    await Share.share(text, sharePositionOrigin: origin);
  }
}
