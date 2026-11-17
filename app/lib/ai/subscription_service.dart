import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The premium subscription's product id in both stores.
const String kPremiumProductId = 'hundred_days_premium';

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

  /// The premium product as the store sells it, with its localised price.
  /// Empty when the store is unavailable or the product is not set up yet.
  Future<List<ProductDetails>> products() async {
    try {
      if (!await _store.isAvailable()) return const <ProductDetails>[];
      final ProductDetailsResponse response =
          await _store.queryProductDetails(<String>{kPremiumProductId});
      return response.productDetails;
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
      if (purchase.productID != kPremiumProductId) continue;
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
