import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hundred_core/hundred_core.dart';

/// A packaged product as its label describes it, per 100 g.
class BarcodeProduct {
  const BarcodeProduct({
    required this.barcode,
    required this.name,
    required this.per100g,
    this.brand,
    this.servingG,
  });

  final String barcode;
  final String name;
  final String? brand;
  final Nutrients per100g;

  /// The label's serving size, when it has one.
  final double? servingG;

  String get displayName =>
      brand == null || brand!.isEmpty || name.contains(brand!)
          ? name
          : '$name ($brand)';
}

/// Why a lookup came back empty.
enum BarcodeProblem { notFound, noNutrition, offline }

class BarcodeLookupException implements Exception {
  const BarcodeLookupException(this.problem);

  final BarcodeProblem problem;

  @override
  String toString() => 'BarcodeLookupException(${problem.name})';
}

/// Looks a barcode up in Open Food Facts, the open product database.
///
/// The one place the nutrition features touch the network, and only when
/// the user scans something: the request carries the barcode and nothing
/// else — no identity, no diary, no account. The answer is a public label.
class BarcodeLookup {
  BarcodeLookup({HttpClient Function()? clientFactory})
      : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  static final RegExp _validBarcode = RegExp(r'^\d{8,14}$');

  static bool isValid(String barcode) => _validBarcode.hasMatch(barcode);

  Future<BarcodeProduct> lookup(String barcode) async {
    final code = barcode.trim();
    if (!isValid(code)) {
      throw const BarcodeLookupException(BarcodeProblem.notFound);
    }
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$code.json',
      <String, String>{
        'fields': 'product_name,product_name_de,product_name_en,brands,'
            'nutriments,serving_quantity',
      },
    );
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = '100days/0.1 (+https://github.com/mikexkllr/100days)';
    try {
      final request = await client.getUrl(uri);
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == HttpStatus.notFound) {
        throw const BarcodeLookupException(BarcodeProblem.notFound);
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const BarcodeLookupException(BarcodeProblem.offline);
      }
      return parse(code, jsonDecode(body));
    } on BarcodeLookupException {
      rethrow;
    } on Object {
      throw const BarcodeLookupException(BarcodeProblem.offline);
    } finally {
      client.close(force: true);
    }
  }

  /// Reads an Open Food Facts v2 product response.
  static BarcodeProduct parse(String barcode, Object? json) {
    if (json is! Map || json['status'] == 0 || json['product'] is! Map) {
      throw const BarcodeLookupException(BarcodeProblem.notFound);
    }
    final product = json['product'] as Map;
    final nutriments = product['nutriments'];
    if (nutriments is! Map) {
      throw const BarcodeLookupException(BarcodeProblem.noNutrition);
    }
    double? read(String key) {
      final value = nutriments[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    var kcal = read('energy-kcal_100g');
    final kj = read('energy-kj_100g') ?? read('energy_100g');
    if (kcal == null && kj != null) kcal = kj / 4.184;
    if (kcal == null) {
      throw const BarcodeLookupException(BarcodeProblem.noNutrition);
    }

    String? text(String key) {
      final value = product[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final serving = product['serving_quantity'];
    final brands = text('brands');
    return BarcodeProduct(
      barcode: barcode,
      name: text('product_name') ??
          text('product_name_de') ??
          text('product_name_en') ??
          barcode,
      brand: brands?.split(',').first.trim(),
      servingG: serving is num
          ? serving.toDouble()
          : serving is String
              ? double.tryParse(serving)
              : null,
      per100g: Nutrients(
        kcal: kcal,
        proteinG: read('proteins_100g') ?? 0,
        carbsG: read('carbohydrates_100g') ?? 0,
        fatG: read('fat_100g') ?? 0,
      ),
    );
  }
}
