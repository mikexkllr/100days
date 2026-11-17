import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/ai/allowance.dart';
import 'package:hundred_days/ai/dartantic_llm_client.dart';
import 'package:hundred_days/ai/gateway.dart';
import 'package:hundred_days/ai/meal_photo.dart';
import 'package:image/image.dart' as img;

void main() {
  group('meal photo', () {
    test('is scaled down and leaves without location or camera data',
        () async {
      final img.Image camera = img.Image(width: 4000, height: 3000);
      camera.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(52, 1);
      camera.exif.imageIfd['Model'] = img.IfdValueAscii('Phone 17 Pro');
      final Uint8List original =
          Uint8List.fromList(img.encodeJpg(camera, quality: 90));
      expect(img.decodeJpg(original)!.exif.isEmpty, isFalse);

      final LlmImage? photo = await prepareMealPhoto(original);
      final img.Image sent = img.decodeJpg(photo!.bytes)!;
      expect(sent.width, kMealPhotoMaxSide);
      expect(sent.height, 768);
      expect(sent.exif.isEmpty, isTrue);
      expect(photo.mimeType, 'image/jpeg');
    });

    test('a portrait photo keeps its orientation, small ones stay small',
        () async {
      final LlmImage? tall = await prepareMealPhoto(Uint8List.fromList(
          img.encodeJpg(img.Image(width: 1500, height: 2000))));
      final img.Image decoded = img.decodeJpg(tall!.bytes)!;
      expect(decoded.height, kMealPhotoMaxSide);
      expect(decoded.width, 768);

      final LlmImage? small = await prepareMealPhoto(Uint8List.fromList(
          img.encodePng(img.Image(width: 640, height: 480))));
      expect(img.decodeJpg(small!.bytes)!.width, 640);
    });

    test('bytes that are not an image are refused', () async {
      expect(await prepareMealPhoto(Uint8List.fromList(<int>[1, 2, 3])),
          isNull);
    });
  });

  group('gateway client', () {
    test('signs with the user token, never forwards a provider key',
        () async {
      late http.BaseRequest seen;
      final GatewayHttpClient client = GatewayHttpClient(
        accessToken: () async => 'user-token',
        publishableKey: 'sb_publishable_x',
        purpose: LlmPurpose.plan,
        inner: MockClient((http.Request request) async {
          seen = request;
          return http.Response('{}', 200);
        }),
      );
      await client.post(
        Uri.parse('https://x.supabase.co/functions/v1/llm-gateway/v1beta/'
            'models/$kAiModel:generateContent'),
        headers: <String, String>{'x-goog-api-key': 'leaked'},
      );
      expect(seen.headers['Authorization'], 'Bearer user-token');
      expect(seen.headers['apikey'], 'sb_publishable_x');
      expect(seen.headers['x-hundred-purpose'], 'plan');
      expect(seen.headers.containsKey('x-goog-api-key'), isFalse);
    });

    test('refuses to call out without a session', () async {
      final GatewayHttpClient client = GatewayHttpClient(
        accessToken: () async => null,
        publishableKey: 'k',
        purpose: LlmPurpose.food,
        inner: MockClient((http.Request _) async => http.Response('', 200)),
      );
      expect(() => client.get(Uri.parse('https://x')), throwsStateError);
    });

    test('points at the gateway function of the configured backend', () {
      expect(
        GatewayProvider.baseUrlFor('https://abc.supabase.co/').toString(),
        'https://abc.supabase.co/functions/v1/llm-gateway/v1beta',
      );
    });
  });

  test('gateway errors map to what the user needs to know', () {
    expect(classifyAiError(Exception('402 quota_exceeded')),
        AiFailure.quotaExceeded);
    expect(classifyAiError('premium_only'), AiFailure.premiumOnly);
    expect(classifyAiError('rate_limited'), AiFailure.rateLimited);
    expect(classifyAiError(Exception('socket closed')), AiFailure.other);
  });

  test('the allowance reads what the server enforces', () {
    final AiAllowance a = AiAllowance.fromJson(<String, dynamic>{
      'tier': 'free',
      'used': 40000,
      'limit': 50000,
    });
    expect(a.premium, isFalse);
    expect(a.fraction, closeTo(0.8, 1e-9));
    expect(a.exhausted, isFalse);
    expect(
      AiAllowance.fromJson(<String, dynamic>{'used': 50000, 'limit': 50000})
          .exhausted,
      isTrue,
    );
    expect(AiAllowance.fromJson(<String, dynamic>{'tier': 'premium'}).premium,
        isTrue);
    expect(AiAllowance.unknown.fraction, isNull);
  });
}
