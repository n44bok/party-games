import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'contact_service.dart';

/// Where the form's messages go: the form at Formspree (formspree.io), which
/// passes every message on to the developer's e-mail address, so that address
/// is not needed for sending.
///
/// If this is ever emptied, the form opens the person's e-mail app instead.
const contactEndpoint = 'https://formspree.io/f/xwloplbk';

/// The address the e-mail fallback writes to.
const contactMailTo = 'n44bok@gmail.com';

/// Posts the message to a form service (see [contactEndpoint]).
class HttpContactService implements ContactService {
  HttpContactService(this.endpoint);

  final String endpoint;

  @override
  Future<ContactResult> send(ContactMessage message) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client
          .postUrl(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 15));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.acceptHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'app': 'Party Games',
            'message': message.message,
            if (message.email != null) ...{
              'email': message.email,
              '_replyto': message.email,
            },
            'language': message.language,
            'platform': message.platform,
          }),
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      await response.drain<void>();
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      if (!ok) debugPrint('Contact form answered ${response.statusCode}');
      return ok ? ContactResult.sent : ContactResult.failed;
    } catch (e) {
      debugPrint('Could not send the message: $e');
      return ContactResult.failed;
    } finally {
      client.close();
    }
  }
}

/// Opens the person's e-mail app with the message ready to send.
class MailContactService implements ContactService {
  const MailContactService();

  @override
  Future<ContactResult> send(ContactMessage message) async {
    final body = [
      message.message,
      '',
      '(${message.platform}, ${message.language})',
    ].join('\n');
    final uri = Uri(
      scheme: 'mailto',
      path: contactMailTo,
      query: _query({'subject': 'Party Games', 'body': body}),
    );
    try {
      final opened = await launchUrl(uri);
      return opened ? ContactResult.mailOpened : ContactResult.failed;
    } catch (e) {
      debugPrint('Could not open the e-mail app: $e');
      return ContactResult.failed;
    }
  }

  /// A query string with spaces as %20 (mail apps do not read "+").
  static String _query(Map<String, String> parameters) => parameters.entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
}

/// The service for this build: the form service if its address is set,
/// otherwise the e-mail app.
ContactService defaultContactService() => contactEndpoint.isEmpty
    ? const MailContactService()
    : HttpContactService(contactEndpoint);
