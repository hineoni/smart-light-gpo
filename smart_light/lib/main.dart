import 'package:flutter/material.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Light Control',
      theme: ThemeData.dark(),
      home: FutureBuilder<bool>(
        future: AuthService.restoreSession(),
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
