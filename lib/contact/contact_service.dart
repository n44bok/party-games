import 'package:flutter/widgets.dart';

/// A message from the "Write to us" form.
class ContactMessage {
  const ContactMessage({
    required this.message,
    this.email,
    required this.language,
    required this.platform,
  });

  final String message;

  /// Where to answer, if the person wants an answer.
  final String? email;

  /// The app's language code and the platform ("ios", "android"): they help to
  /// understand the message, nothing else.
  final String language;
  final String platform;
}

/// What came of sending.
enum ContactResult {
  /// The message went off.
  sent,

  /// The person's e-mail app was opened with the message ready to send (the
  /// fallback when no form service is set up).
  mailOpened,

  /// It did not work (no connection, the service said no).
  failed,
}

/// Sends the message to the developer.
abstract class ContactService {
  Future<ContactResult> send(ContactMessage message);
}

/// Sends nothing (tests, and as the fallback when there is no scope).
class NoContactService implements ContactService {
  const NoContactService();

  @override
  Future<ContactResult> send(ContactMessage message) async =>
      ContactResult.failed;
}

/// Makes the [ContactService] available to descendants.
class ContactScope extends InheritedWidget {
  const ContactScope({super.key, required this.service, required super.child});

  final ContactService service;

  static ContactService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ContactScope>()?.service ??
      const NoContactService();

  @override
  bool updateShouldNotify(ContactScope oldWidget) =>
      service != oldWidget.service;
}
