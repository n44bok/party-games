import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../contact/captcha.dart';
import '../contact/contact_service.dart';
import '../data/strings.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_background.dart';

/// "Write to us": a short form for wishes, ideas and bug reports, with a small
/// question that only a person is expected to answer.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key, this.random});

  /// Injectable for tests.
  final Random? random;

  static const maxMessageLength = 1000;
  static const minMessageLength = 5;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _message = TextEditingController();
  final _email = TextEditingController();
  final _answer = TextEditingController();
  late final MathCaptcha _captcha = MathCaptcha(widget.random);

  String? _messageError;
  String? _emailError;
  String? _answerError;
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = Strings.of(context);
    FocusScope.of(context).unfocus();
    final text = _message.text.trim();
    final email = _email.text.trim();
    setState(() {
      _messageError = text.length < ContactScreen.minMessageLength
          ? s['contact_too_short']
          : null;
      _emailError = looksLikeEmail(email) ? null : s['contact_bad_email'];
      _answerError = _captcha.accepts(_answer.text)
          ? null
          : s['contact_wrong_answer'];
      // A wrong answer gets a new question: it cannot be guessed by trying.
      if (_answerError != null) {
        _captcha.refresh();
        _answer.clear();
      }
    });
    if (_messageError != null || _emailError != null || _answerError != null) {
      return;
    }

    setState(() => _sending = true);
    final result = await ContactScope.read(context).send(
      ContactMessage(
        message: text,
        email: email.isEmpty ? null : email,
        language: s.code,
        platform: defaultTargetPlatform.name,
      ),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    switch (result) {
      case ContactResult.sent:
        setState(() => _sent = true);
      case ContactResult.mailOpened:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s['contact_mail_opened'])));
      case ContactResult.failed:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(s['contact_error'])));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          s['contact_title'],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 36),
        ),
      ),
      body: GradientBackground(
        dark: true,
        child: SafeArea(child: _sent ? _buildThanks(s) : _buildForm(s)),
      ),
    );
  }

  Widget _buildThanks(Strings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: GlassCard(
                radius: 32,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 36,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 56,
                      color: Color(0xFFF06FB5),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      s['contact_sent_title'],
                      key: const Key('contactThanks'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s['contact_sent'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GradientButton(
            label: s['done'],
            height: 60,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    String? error,
  }) {
    OutlineInputBorder border(double alpha) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: alpha)),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: error,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      enabledBorder: border(0.16),
      focusedBorder: border(0.6),
      border: border(0.16),
    );
  }

  Widget _buildForm(Strings s) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Text(
              s['contact_intro'],
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('contactMessage'),
            controller: _message,
            minLines: 5,
            maxLines: 9,
            maxLength: ContactScreen.maxMessageLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(
              label: s['contact_message_label'],
              hint: s['contact_message_hint'],
              error: _messageError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contactEmail'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: _decoration(
              label: s['contact_email_label'],
              hint: s['contact_email_hint'],
              error: _emailError,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.format('contact_captcha', {
                    'a': _captcha.a,
                    'b': _captcha.b,
                  }),
                  key: const Key('contactQuestion'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: s['contact_new_question'],
                onPressed: () => setState(() {
                  _captcha.refresh();
                  _answer.clear();
                  _answerError = null;
                }),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('contactCaptcha'),
            controller: _answer,
            keyboardType: TextInputType.number,
            maxLength: 3,
            decoration: _decoration(
              label: s['contact_answer'],
              error: _answerError,
            ).copyWith(counterText: ''),
          ),
          const SizedBox(height: 8),
          Text(
            s['contact_privacy'],
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 18),
          // Nothing to do while the message is on its way.
          IgnorePointer(
            ignoring: _sending,
            child: Opacity(
              opacity: _sending ? 0.6 : 1,
              child: GradientButton(
                key: const Key('contactSend'),
                label: _sending ? s['contact_sending'] : s['contact_send'],
                icon: Icons.send_rounded,
                height: 60,
                onPressed: _send,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
