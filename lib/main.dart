import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/content_repository.dart';
import 'data/content_scope.dart';
import 'data/strings.dart';
import 'screens/home_screen.dart';

void main() => runApp(const PartyGamesApp());

class PartyGamesApp extends StatelessWidget {
  const PartyGamesApp({super.key, this.repository});

  /// Override to supply content from somewhere other than the asset bundle.
  final ContentRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Party Games',
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
      builder: (context, child) => ContentScope(
        repository: repository ?? ContentRepository(),
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
