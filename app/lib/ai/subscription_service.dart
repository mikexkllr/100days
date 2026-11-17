import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How often a premium subscription renews.
enum PremiumPeriod { monthly, yearly }

/// The premium subscriptions, with the same product ids in the App Store
/// (one subscription group) and on Google Play (one base plan each). The
/// server accepts exactly these (`PREMIUM_PRODUCT_IDS` in verify-purchase).
const Map<String, PremiumPeriod> kPremiumProducts = <String, PremiumPeriod>{
  'hundred_days_premium_monthly': PremiumPeriod.monthly,
  'hundred_days_premium_yearly': PremiumPeriod.yearly,
};

/// What a purchase attempt ended in.
enum PurchaseOutcome { premium, pending, cancelled, failed, notVerified }

/// Premium through the stores' own billing.
///
/// The app never decides that it is premium. Every purchase — and every
/// restore — is handed to the `verify-purchase` function, which asks the
/// store and records the subscription on the server. The AI gateway reads
/// the tier from there.
class SubscriptionService {
  SubscriptionService(this._client, {InAppPurchase? store})
      : _store = store ?? InAppPurchase.instance;

  final SupabaseClient _client;
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _updates;
  final StreamController<PurchaseOutcome> _outcomes =
      StreamController<PurchaseOutcome>.broadcast();

  Stream<PurchaseOutcome> get outcomes => _outcomes.stream;

  /// Starts listening for purchases, including ones that finish after the
  /// app was closed mid-purchase.
  void start() {
    _updates ??= _store.purchaseStream.listen(_onPurchases, onError: (Object _) {
      _outcomes.add(PurchaseOutcome.failed);
    });
  }

  /// The premium subscriptions as the store sells them, with localised
  /// prices, monthly first. Empty when the store is unavailable or the
  /// products are not set up yet.
  Future<List<ProductDetails>> products() async {
    try {
      if (!await _store.isAvailable()) return const <ProductDetails>[];
      final ProductDetailsResponse response =
          await _store.queryProductDetails(kPremiumProducts.keys.toSet());
      return <ProductDetails>[
        for (final String id in kPremiumProducts.keys)
          // Google Play lists a product once per offer; one is enough.
          ...response.productDetails
              .where((ProductDetails p) => p.id == id)
              .take(1),
      ];
    } on Object {
      // No store on this device (emulator without Play, desktop).
      return const <ProductDetails>[];
    }
  }

  Future<void> buy(ProductDetails product) => _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );

  /// Re-delivers past purchases through [outcomes], e.g. on a new phone.
  Future<void> restore() => _store.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (!kPremiumProducts.containsKey(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _outcomes.add(PurchaseOutcome.pending);
        case PurchaseStatus.canceled:
          _outcomes.add(PurchaseOutcome.cancelled);
        case PurchaseStatus.error:
          _outcomes.add(PurchaseOutcome.failed);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _outcomes.add(await _verify(purchase)
              ? PurchaseOutcome.premium
              : PurchaseOutcome.notVerified);
      }
      // The store keeps redelivering a purchase until it is completed — even
      // one the server refused, which must not loop forever.
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

  Future<bool> _verify(PurchaseDetails purchase) async {
    final bool apple = Platform.isIOS || Platform.isMacOS;
    // App Store: the transaction id, which the server looks up with Apple.
    // Google Play: the purchase token.
    final String? token = apple
        ? purchase.purchaseID
        : purchase.verificationData.serverVerificationData;
    if (token == null || token.isEmpty) return false;
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'verify-purchase',
        body: <String, dynamic>{
          'platform': apple ? 'app_store' : 'google_play',
          'productId': purchase.productID,
          'token': token,
        },
      );
      final Object? data = response.data;
      return data is Map && data['premium'] == true;
    } on Object {
      return false;
    }
  }

  Future<void> dispose() async {
    await _updates?.cancel();
    await _outcomes.close();
  }
}
