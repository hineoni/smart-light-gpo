import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/app_settings.dart';
import 'theme/light_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(MyApp(settings: settings));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<bool> _restoreSession;

  @override
  void initState() {
    super.initState();
    _restoreSession = AuthService.restoreSession();
    widget.settings.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Light Control',
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Avenir Next',
        textTheme: readableTextTheme(Brightness.dark),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF1C1B1F),
          indicatorColor: Color(0xFF3F51B5),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      themeMode: widget.settings.themeMode,
      theme: widget.settings.theme == AppTheme.emerald
          ? buildGreenTheme()
          : widget.settings.theme == AppTheme.indigo
          ? buildIndigoTheme()
          : buildLightTheme(),
      locale: widget.settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: FutureBuilder<bool>(
        future: _restoreSession,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return snapshot.data == true
              ? const MainNavigationScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
