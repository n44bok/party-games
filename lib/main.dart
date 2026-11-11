import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/content_repository.dart';
import 'data/content_scope.dart';
import 'data/settings.dart';
import 'data/strings.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();
  runApp(PartyGamesApp(settings: settings));
}

class PartyGamesApp extends StatefulWidget {
  const PartyGamesApp({super.key, this.repository, this.settings});

  /// Override to supply content from somewhere other than the asset bundle.
  final ContentRepository? repository;

  /// Preferences; defaults to fresh in-memory ones (used by tests).
  final SettingsController? settings;

  @override
  State<PartyGamesApp> createState() => _PartyGamesAppState();
}

class _PartyGamesAppState extends State<PartyGamesApp> {
  late final SettingsController _settings =
      widget.settings ?? SettingsController();

  @override
  void dispose() {
    // Only dispose what we created ourselves.
    if (widget.settings == null) _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language changes.
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => _buildApp(),
    );
  }

  Widget _buildApp() {
    return MaterialApp(
      title: 'Party Games',
      locale: _settings.locale,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFB45CF5),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF140B2B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          selectedColor: const Color(0xFFB45CF5),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          labelStyle: const TextStyle(color: Colors.white),
          shape: const StadiumBorder(),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E1238),
          indicatorColor: const Color(0xFFB45CF5).withValues(alpha: 0.35),
        ),
      ),
      supportedLocales: [for (final c in Strings.supported) Locale(c)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => SettingsScope(
        settings: _settings,
        child: ContentScope(
          repository: widget.repository ?? ContentRepository(),
          child: child!,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
