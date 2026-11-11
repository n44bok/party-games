import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Asks the person for what the law and the stores require before ads are
/// requested:
///
/// * **Google's consent form (UMP)** for people in the EU, the UK and other
///   places that need it. The form itself is made in the AdMob console
///   ("Privacy & messaging"); with no message there, nothing is shown.
/// * **App Tracking Transparency (ATT)** on iOS: the system's "Allow this app
///   to track you?" question.
///
/// Every call swallows errors: a failure here must never stop the app.
class AdConsent {
  const AdConsent();

  /// To try the form on a phone or simulator outside the EU, run with
  /// `--dart-define=CONSENT_TEST_EEA=true` (debug builds only).
  static const _testEea = bool.fromEnvironment('CONSENT_TEST_EEA');

  /// Updates the consent information and shows the form if one is needed.
  Future<void> gatherConsent() async {
    final updated = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(
          consentDebugSettings: kDebugMode && _testEea
              ? ConsentDebugSettings(
                  debugGeography: DebugGeography.debugGeographyEea,
                )
              : null,
        ),
        () => updated.complete(),
        (error) {
          debugPrint('Consent info update failed: ${error.message}');
          updated.complete();
        },
      );
      await updated.future;
      await ConsentForm.loadAndShowConsentFormIfRequired((error) {
        if (error != null) debugPrint('Consent form: ${error.message}');
      });
    } catch (e) {
      debugPrint('Could not gather consent: $e');
    }
  }

  /// iOS only: the system's tracking question, if it was not answered yet.
  Future<void> requestTracking() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // The question only shows once the app is on screen and active.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('Could not ask for tracking permission: $e');
    }
  }

  /// Whether ads may be requested now.
  Future<bool> canRequestAds() async {
    try {
      return await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      return false;
    }
  }

  /// Whether people must be able to change their choice (they are in a place
  /// where consent is required): then Settings shows an entry for it.
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Opens the form where people can change their choice.
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) debugPrint('Privacy options: ${error.message}');
      });
    } catch (e) {
      debugPrint('Could not show the privacy options: $e');
    }
  }
}
