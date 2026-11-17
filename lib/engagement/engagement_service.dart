import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';

/// Android listing. The App Store link is added here once the iOS app has an
/// id (the number in its App Store URL).
const playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.n44bok.partygames';
const appStoreId = '6833983705';

/// Where friends can get the app on this platform, or `null` if not known.
String? get shareUrl {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => playStoreUrl,
    TargetPlatform.iOS =>
      appStoreId.isEmpty ? null : 'https://apps.apple.com/app/id$appStoreId',
    _ => null,
  };
}

/// Asking for a store rating and sharing the app with friends.
abstract class EngagementService {
  /// Shows the store's own rating sheet. The store decides whether it appears.
  Future<void> requestReview();

  /// Opens the app's page in the store, where people can write a review.
  /// Falls back to the rating sheet when the page is not known.
  Future<void> openStorePage();

  /// Opens the system share sheet with [text]. [origin] is where the sheet
  /// points to on iPad.
  Future<void> share(String text, {Rect? origin});
}

/// Does nothing (tests, and as the fallback when there is no scope).
class NoEngagementService implements EngagementService {
  const NoEngagementService();

  @override
  Future<void> requestReview() async {}

  @override
  Future<void> openStorePage() async {}

  @override
  Future<void> share(String text, {Rect? origin}) async {}
}

class StoreEngagementService implements EngagementService {
  const StoreEngagementService();

  @override
  Future<void> requestReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (e) {
      debugPrint('Could not ask for a review: $e');
    }
  }

  @override
  Future<void> openStorePage() async {
    try {
      final review = InAppReview.instance;
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          appStoreId.isEmpty) {
        await requestReview(); // no page to open yet
        return;
      }
      await review.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      debugPrint('Could not open the store page: $e');
    }
  }

  @override
  Future<void> share(String text, {Rect? origin}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
    } catch (e) {
      debugPrint('Could not share: $e');
    }
  }
}

/// Makes the [EngagementService] available to descendants.
class EngagementScope extends InheritedWidget {
  const EngagementScope({
    super.key,
    required this.service,
    required super.child,
  });

  final EngagementService service;

  static EngagementService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EngagementScope>()?.service ??
      const NoEngagementService();

  @override
  bool updateShouldNotify(EngagementScope oldWidget) =>
      service != oldWidget.service;
}
