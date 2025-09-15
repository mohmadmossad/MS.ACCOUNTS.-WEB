import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:_/theme.dart';
import 'package:_/pages/dashboard_page.dart';
import 'package:_/pages/login_page.dart';
import 'package:_/services/local_db.dart';
import 'package:_/services/auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDb.I.init();
  await AuthService.I.bootstrap();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المحاسب الذكي',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    // Rebuild on settings changes (login/logout)
    return ValueListenableBuilder(
      valueListenable: LocalDb.I.settings.listenable(),
      builder: (context, _, __) {
        final auth = LocalDb.I.settings.get('auth')?.cast<String, dynamic>() ?? {};
        final loggedIn = (auth['loggedIn'] ?? false) == true;
        return loggedIn ? const DashboardPage() : const LoginPage();
      },
    );
  }
}
