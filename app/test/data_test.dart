import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hundred_core/hundred_core.dart';
import 'package:hundred_days/data/app_repository.dart';
import 'package:hundred_days/data/barcode_lookup.dart';
import 'package:hundred_days/data/device_profile.dart';
import 'package:hundred_days/data/llm_runtime.dart';
import 'package:hundred_days/data/model_download.dart';

import 'helpers.dart';

const BodyProfile _body = BodyProfile(
  sex: BiologicalSex.male,
  ageYears: 31,
  heightCm: 182,
  weightKg: 84,
  activityLevel: ActivityLevel.moderate,
);

DeviceProfile _phone(int gb) =>
    DeviceProfile(model: 'Test', ramMb: gb * 1024 - 400, supportsLocalAi: true);

void main() {
  group('model choice', () {
    test('picks the strongest model that fits, never the huge one', () {
      expect(recommendedModel(_phone(3))!.id, 'qwen3.5-0.8b-q4');
      expect(recommendedModel(_phone(4))!.id, 'qwen3.5-0.8b-q4');
      expect(recommendedModel(_phone(6))!.id, 'qwen3.5-2b-q4');
      expect(recommendedModel(_phone(8))!.id, 'gemma-4-e2b-q4');
      expect(recommendedModel(_phone(16))!.id, 'gemma-4-e2b-q4');
    });

    test('unknown memory gets the smallest, unsupported hardware none', () {
      expect(recommendedModel(DeviceProfile.unknown)!.tier, ModelTier.light);
      expect(
        recommendedModel(const DeviceProfile(
          model: 'Old',
          ramMb: 8192,
          supportsLocalAi: false,
        )),
        isNull,
      );
    });

    test('reported memory rounds to the number on the box', () {
      expect(_phone(8).advertisedRamGb, 8);
      expect(_phone(12).advertisedRamGb, 12);
      expect(const DeviceProfile(model: '', ramMb: 5800, supportsLocalAi: true)
          .advertisedRamGb, 6);
    });

    test('every model is pinned to a revision and a checksum', () {
      for (final LocalModelSpec spec in kModelCatalog) {
        expect(spec.revision, matches(RegExp(r'^[0-9a-f]{40}$')), reason: spec.id);
        expect(spec.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: spec.id);
        expect(spec.downloadUri.scheme, 'https');
        expect(spec.downloadUri.path, contains(spec.revision));
      }
    });
  });

  group('model download', () {
    late HttpServer server;
    late Directory dir;
    late List<int> payload;
    final List<String?> ranges = <String?>[];

    setUp(() async {
      payload = List<int>.generate(300000, (int i) => (i * 31) % 256);
      dir = await Directory.systemTemp.createTemp('model-test');
      ranges.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        final String? range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        var start = 0;
        if (range != null) {
          start = int.parse(range.substring(6, range.length - 1));
          request.response.statusCode = HttpStatus.partialContent;
        }
        request.response.add(payload.sublist(start));
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });

    LocalModelSpec spec(String sha) => LocalModelSpec(
          id: 'test',
          name: 'Test',
          tier: ModelTier.light,
          repository: 'x/y',
          revision: 'r',
          fileName: 'test.gguf',
          sizeBytes: payload.length,
          sha256: sha,
          minRamMb: 0,
          license: 'MIT',
        );

    Uri source() => Uri.parse('http://127.0.0.1:${server.port}/model');

    test('resumes a partial file and verifies it before naming it', () async {
      final File target = File('${dir.path}/test.gguf');
      await ModelDownloader.partialFileFor(target)
          .writeAsBytes(payload.sublist(0, 100000));

      final File done = await ModelDownloader().download(
        spec(sha256.convert(payload).toString()),
        target,
        source: source(),
      );

      expect(ranges.single, 'bytes=100000-');
      expect(await done.readAsBytes(), payload);
      expect(ModelDownloader.partialFileFor(target).existsSync(), isFalse);
    });

    test('a file that does not match its checksum is thrown away', () async {
      final File target = File('${dir.path}/test.gguf');
      await expectLater(
        ModelDownloader().download(spec('0' * 64), target, source: source()),
        throwsA(isA<ModelChecksumMismatch>()),
      );
      expect(target.existsSync(), isFalse);
      expect(ModelDownloader.partialFileFor(target).existsSync(), isFalse);
    });
  });

  group('barcode lookup', () {
    test('reads an Open Food Facts product', () {
      final BarcodeProduct product = BarcodeLookup.parse('4008400401621', <String, dynamic>{
        'status': 1,
        'product': <String, dynamic>{
          'product_name': 'Haferflocken kernig',
          'brands': 'Kölln, Peter Kölln',
          'serving_quantity': '40',
          'nutriments': <String, dynamic>{
            'energy-kcal_100g': 372,
            'proteins_100g': 13.5,
            'carbohydrates_100g': 58.7,
            'fat_100g': 7,
          },
        },
      });
      expect(product.displayName, 'Haferflocken kernig (Kölln)');
      expect(product.per100g.kcal, 372);
      expect(product.servingG, 40);
    });

    test('falls back to kilojoules and refuses a product without values', () {
      final BarcodeProduct kj = BarcodeLookup.parse('12345678', <String, dynamic>{
        'product': <String, dynamic>{
          'product_name': 'Saft',
          'nutriments': <String, dynamic>{'energy-kj_100g': 188.3},
        },
      });
      expect(kj.per100g.kcal, closeTo(45, 0.1));
      expect(
        () => BarcodeLookup.parse('12345678', <String, dynamic>{'status': 0}),
        throwsA(isA<BarcodeLookupException>()),
      );
      expect(BarcodeLookup.isValid('4008400401621'), isTrue);
      expect(BarcodeLookup.isValid('12ab'), isFalse);
    });
  });

  group('privacy on the wire', () {
    test('friends get neither body stats nor private habits', () async {
      final repository = await testRepository();
      final Challenge challenge = Challenge(
        id: 'c',
        goal: const Goal(
          archetype: GoalArchetype.loseFat,
          statement: '8 kg runter',
          body: _body,
          nutrition: NutritionGoals(kcalTarget: 2100),
        ),
        habits: <Habit>[
          Habit.fromCategory(HabitCategory.noFap),
          Habit.fromCategory(HabitCategory.nutrition),
        ],
        startDay: DayKey.today(),
        sharing: const SharingPrefs(privateHabits: <String>{'noFap'}),
      );
      await repository.startChallenge(challenge);
      await repository.checkIn(
        habit: challenge.habits.first,
        day: DayKey.today(),
        challenge: challenge,
      );
      await repository.logFood(FoodEntry(
        id: 'f1',
        day: DayKey.today(),
        meal: MealSlotKind.lunch,
        name: 'Currywurst',
        grams: 200,
        nutrients: kFoodById['currywurst']!.forGrams(200),
        source: FoodSource.database,
      ));

      final List<FeedEvent> raw =
          await repository.store.eventsOf(repository.did);
      // Everything a friend can read: the payloads that are not sealed.
      final String wire = raw
          .where((FeedEvent e) => e.type != FeedEventType.private)
          .map((FeedEvent e) => jsonEncode(e.payload))
          .join();
      expect(wire, isNot(contains('weightKg')), reason: 'body stats leaked');
      expect(wire, isNot(contains('noFap')), reason: 'private habit leaked');
      expect(wire, isNot(contains('Currywurst')), reason: 'diary leaked');
      expect(wire, isNot(contains('"preset"')), reason: 'targets leaked');
      // The sealed ones say nothing in the clear either.
      expect(raw.map((FeedEvent e) => jsonEncode(e.payload)).join(),
          isNot(contains('Currywurst')));

      // What a friend's device computes from those bytes.
      final UserProjection asFriend = projectUser(repository.did, raw);
      expect(asFriend.challenge!.habits.map((Habit h) => h.id),
          <String>['nutrition']);
      expect(asFriend.foodByDay, isEmpty);

      // And what the owner sees.
      final AppSnapshot mine = await repository.snapshot();
      expect(mine.challenge!.goal.body!.weightKg, 84);
      expect(mine.me.intakeOn(DayKey.today()).entries.single.name, 'Currywurst');
      expect(mine.me.logsByDay[DayKey.today().toString()]!.entries.single.habitId,
          'noFap');
      expect(mine.plan!.nutrition!.kcal, 2100);

      // The private check-in earns XP at home, but the league ranks by what
      // friends can verify — the same number on every device.
      expect(mine.me.lifetimeXp, greaterThan(0));
      expect(
        mine.league.entries
            .firstWhere((LeagueEntry e) => e.did == repository.did)
            .weeklyXp,
        0,
      );
    });
  });
}
