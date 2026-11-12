/// The id of the Premium subscription in both stores (App Store Connect and
/// Google Play Console): create the product with exactly this id.
const premiumProductId = 'premium_year';

/// How long Premium is trusted without the store confirming it again.
///
/// Without a server the app cannot ask the store when a subscription ends, so
/// it works with a "lease": every confirmation from the store lets Premium run
/// until [premiumUntil], and when no further confirmation comes, Premium
/// simply runs out.
///
/// * **iPhone:** every renewal is a new transaction that the store delivers to
///   the app when it starts. A transaction pays for a year, plus a few days of
///   grace for a late renewal.
/// * **Android:** the store lists the subscriptions that are active right now
///   whenever the app asks (it does on every start), so each answer is
///   trusted for a week, which also covers being offline.
DateTime premiumUntil({
  required DateTime now,
  required bool isAndroid,
  DateTime? transactionDate,
}) {
  if (isAndroid) return now.add(const Duration(days: 7));
  return (transactionDate ?? now).add(const Duration(days: 365 + 3));
}
