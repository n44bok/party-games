import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/settings.dart';
import 'premium_lease.dart';
import 'purchase_service.dart';

/// Premium through the App Store and Google Play (the `in_app_purchase`
/// plugin).
///
/// What the store confirms is turned into [SettingsController.grantPremium]
/// (see [premiumUntil] for how long a confirmation counts). Every call
/// swallows errors: the store being unreachable must never break the app.
class StorePurchaseService extends PurchaseService {
  StorePurchaseService(this._settings);

  final SettingsController _settings;

  /// Purchases exist only on phones.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  InAppPurchase get _iap => InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  bool _busy = false;
  Completer<PurchaseResult>? _waiting;
  bool _restoring = false;

  @override
  String? get price => _product?.price;

  @override
  bool get canBuy => _product != null;

  @override
  bool get busy => _busy;

  /// Starts listening to the store and looks the product up. Never throws.
  Future<void> initialize() async {
    if (!isSupported) return;
    try {
      if (!await _iap.isAvailable()) return;
      _subscription = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) => debugPrint('Purchase stream error: $e'),
      );
      final response = await _iap.queryProductDetails({premiumProductId});
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
        notifyListeners();
      } else {
        debugPrint('Premium product not found: ${response.notFoundIDs}');
      }
      // Android lists the subscriptions that are active, without asking the
      // person anything: this keeps Premium going. (On iPhone renewals arrive
      // by themselves.)
      if (_isAndroid) await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Could not start the store: $e');
    }
  }

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  void _finish(PurchaseResult result) {
    _setBusy(false);
    final waiting = _waiting;
    _waiting = null;
    _restoring = false;
    if (waiting != null && !waiting.isCompleted) waiting.complete(result);
  }

  @override
  Future<PurchaseResult> buy() async {
    final product = _product;
    if (product == null) return PurchaseResult.unavailable;
    if (_busy) return PurchaseResult.failed;
    _setBusy(true);
    final waiting = _waiting = Completer<PurchaseResult>();
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) _finish(PurchaseResult.failed);
    } catch (e) {
      debugPrint('Could not start the purchase: $e');
      _finish(PurchaseResult.failed);
    }
    return waiting.future;
  }

  @override
  Future<PurchaseResult> restore() async {
    if (!isSupported || _subscription == null) {
      return PurchaseResult.unavailable;
    }
    if (_busy) return PurchaseResult.failed;
    _setBusy(true);
    _restoring = true;
    final waiting = _waiting = Completer<PurchaseResult>();
    try {
      await _iap.restorePurchases();
      // The store answers through the stream; silence means nothing was found.
      unawaited(
        Future<void>.delayed(const Duration(seconds: 6), () {
          if (_waiting == waiting) _finish(PurchaseResult.nothingToRestore);
        }),
      );
    } catch (e) {
      debugPrint('Could not restore purchases: $e');
      _finish(PurchaseResult.failed);
    }
    return waiting.future;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != premiumProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _setBusy(true);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final now = DateTime.now();
          final until = premiumUntil(
            now: now,
            isAndroid: _isAndroid,
            transactionDate: _transactionDate(purchase),
          );
          if (until.isAfter(now)) {
            await _settings.grantPremium(until);
            _finish(
              _restoring ? PurchaseResult.restored : PurchaseResult.purchased,
            );
          }
        case PurchaseStatus.error:
          debugPrint('Purchase failed: ${purchase.error?.message}');
          _finish(PurchaseResult.failed);
        case PurchaseStatus.canceled:
          _finish(PurchaseResult.cancelled);
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          debugPrint('Could not complete the purchase: $e');
        }
      }
    }
  }

  /// When the store says the transaction happened (milliseconds since 1970).
  static DateTime? _transactionDate(PurchaseDetails purchase) {
    final millis = int.tryParse(purchase.transactionDate ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
