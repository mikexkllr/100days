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
///
/// [retryLater]: paid, but the server could not be reached to confirm it.
/// The purchase is left open, so the store hands it over again on the next
/// start and the confirmation is retried.
enum PurchaseOutcome {
  premium,
  pending,
  cancelled,
  failed,
  notVerified,
  retryLater,
}

/// What a restore found.
enum RestoreResult { premium, nothing, failed }

/// The server's verdict on one purchase.
enum _Verdict { premium, refused, unreachable }

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

  /// Re-delivers past purchases through [outcomes], e.g. on a new phone,
  /// and says what came of it: the store only reports what it found, so
  /// "nothing" is a short silence.
  Future<RestoreResult> restore() async {
    start();
    final Completer<RestoreResult> result = Completer<RestoreResult>();
    final StreamSubscription<PurchaseOutcome> listener =
        _outcomes.stream.listen((PurchaseOutcome outcome) {
      if (result.isCompleted) return;
      if (outcome == PurchaseOutcome.premium) {
        result.complete(RestoreResult.premium);
      } else if (outcome == PurchaseOutcome.retryLater ||
          outcome == PurchaseOutcome.failed) {
        result.complete(RestoreResult.failed);
      }
    });
    try {
      await _store.restorePurchases();
    } on Object {
      if (!result.isCompleted) result.complete(RestoreResult.failed);
    }
    final Timer quiet = Timer(const Duration(seconds: 6), () {
      if (!result.isCompleted) result.complete(RestoreResult.nothing);
    });
    try {
      return await result.future;
    } finally {
      quiet.cancel();
      await listener.cancel();
    }
  }

  /// Renewals: the App Store hands each one to the purchase listener at the
  /// next start; Google Play does not, so on Android the active
  /// subscriptions are handed over again quietly, once per start, and the
  /// server learns the new expiry from the store.
  Future<void> refreshRenewals() async {
    start();
    if (!Platform.isAndroid) return;
    try {
      if (await _store.isAvailable()) await _store.restorePurchases();
    } on Object {
      // No store, no network: the next start tries again.
    }
  }

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
          final _Verdict verdict = await _verify(purchase);
          _outcomes.add(switch (verdict) {
            _Verdict.premium => PurchaseOutcome.premium,
            _Verdict.refused => PurchaseOutcome.notVerified,
            _Verdict.unreachable => PurchaseOutcome.retryLater,
          });
          // Paid, but not confirmed: leave it open, so the store hands it
          // over again and the next start retries. Completing it now would
          // lose a purchase the user paid for.
          if (verdict == _Verdict.unreachable) continue;
      }
      // The store keeps redelivering a purchase until it is completed — even
      // one the server refused, which must not loop forever.
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
    }
  }

  Future<_Verdict> _verify(PurchaseDetails purchase) async {
    final bool apple = Platform.isIOS || Platform.isMacOS;
    // App Store: the transaction id, which the server looks up with Apple.
    // Google Play: the purchase token.
    final String? token = apple
        ? purchase.purchaseID
        : purchase.verificationData.serverVerificationData;
    if (token == null || token.isEmpty) return _Verdict.refused;
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
      return data is Map && data['premium'] == true
          ? _Verdict.premium
          : _Verdict.refused;
    } on FunctionException catch (error) {
      // A 4xx is the server's answer; a 5xx means it could not decide.
      return error.status >= 500 ? _Verdict.unreachable : _Verdict.refused;
    } on Object {
      return _Verdict.unreachable;
    }
  }

  Future<void> dispose() async {
    await _updates?.cancel();
    await _outcomes.close();
  }
}
