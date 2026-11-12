import 'package:flutter/widgets.dart';

/// What came of a purchase or a restore.
enum PurchaseResult {
  /// Premium was bought and is active.
  purchased,

  /// An earlier purchase was found and Premium is active again.
  restored,

  /// A restore found nothing.
  nothingToRestore,

  /// The person backed out.
  cancelled,

  /// Something went wrong (no connection, store error, ...).
  failed,

  /// The store or the product is not available (yet).
  unavailable,
}

/// What the Premium screen needs from the store. The real implementation talks
/// to the App Store and Google Play ([StorePurchaseService]); this base is
/// also the "no store" fallback used in tests.
///
/// It tells its listeners when [price], [canBuy] or [busy] change.
abstract class PurchaseService extends ChangeNotifier {
  /// The price as the store shows it for this person, in their currency (for
  /// example "$4.99" or "199,00 ₴"), or `null` until it is known.
  String? get price;

  /// Whether the product was found in the store, so it can be bought.
  bool get canBuy;

  /// A purchase or a restore is in progress.
  bool get busy;

  /// Starts the purchase.
  Future<PurchaseResult> buy();

  /// Looks for purchases made earlier (new phone, reinstall).
  Future<PurchaseResult> restore();
}

class NoPurchaseService extends PurchaseService {
  @override
  String? get price => null;

  @override
  bool get canBuy => false;

  @override
  bool get busy => false;

  @override
  Future<PurchaseResult> buy() async => PurchaseResult.unavailable;

  @override
  Future<PurchaseResult> restore() async => PurchaseResult.unavailable;
}

/// Makes the [PurchaseService] available to descendants.
class PurchaseScope extends InheritedNotifier<PurchaseService> {
  const PurchaseScope({
    super.key,
    required PurchaseService service,
    required super.child,
  }) : super(notifier: service);

  /// The service, rebuilding the caller when it changes. Without a scope
  /// there is no store.
  static PurchaseService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PurchaseScope>()?.notifier ??
      _none;

  static PurchaseService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PurchaseScope>()?.notifier ?? _none;

  static final PurchaseService _none = NoPurchaseService();
}
