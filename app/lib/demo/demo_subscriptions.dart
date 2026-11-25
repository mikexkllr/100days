import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../ai/subscription_service.dart';

/// The two Premium plans at their store prices, without a store: the demo
/// shows the AI screen as a free account sees it, for the screenshots the
/// App Store asks for with every subscription. Buying does nothing.
class DemoSubscriptionService extends SubscriptionService {
  DemoSubscriptionService(super.client, this.locale);

  final Locale locale;

  @override
  void start() {}

  @override
  Future<List<ProductDetails>> products() async {
    final bool german = locale.languageCode == 'de';
    ProductDetails plan(String id, String title, double price) =>
        ProductDetails(
          id: id,
          title: title,
          description: title,
          price: german
              ? '${price.toStringAsFixed(2).replaceAll('.', ',')} €'
              : '€${price.toStringAsFixed(2)}',
          rawPrice: price,
          currencyCode: 'EUR',
          currencySymbol: '€',
        );
    return <ProductDetails>[
      plan('hundred_days_premium_monthly', 'Premium', 2.99),
      plan('hundred_days_premium_yearly', 'Premium', 19.99),
    ];
  }

  @override
  Future<void> buy(ProductDetails product) async {}

  @override
  Future<RestoreResult> restore() async => RestoreResult.nothing;
}
