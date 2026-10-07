import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/device_model.dart';
import 'screens/add_device_screen.dart';
import 'screens/api_test_screen.dart';
import 'screens/ble_provisioning_screen.dart';
import 'screens/device_control_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/password_reset_screen.dart';
import 'screens/positioning_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_settings.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';

GoRouter createAppRouter(Future<bool> restoreSession) {
  const publicPaths = {
    '/login',
    '/register',
    '/verify-email',
    '/password-reset',
  };

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      await restoreSession;
      final signedIn = AuthService.accessToken != null;
      final path = state.uri.path;

      if (path == '/') return signedIn ? '/devices' : '/login';
      if (!signedIn && !publicPaths.contains(path)) return '/login';
      if (signedIn && path == '/login') return '/devices';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => EmailVerificationScreen(
          email: state.uri.queryParameters['email'] ?? '',
          verificationCode: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/password-reset',
        builder: (_, _) => const PasswordResetScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainNavigationScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/devices',
                builder: (_, _) => const DeviceListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/positioning',
                builder: (_, _) => const PositioningScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) =>
                    SettingsScreen(settings: AppSettings.instance),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/device/:deviceId',
        builder: (_, state) {
          final deviceId = state.pathParameters['deviceId']!;
          final extra = state.extra;
          if (extra is DeviceModel && extra.id == deviceId) {
            return DeviceControlScreen(device: extra);
          }
          return _DeviceControlRoute(deviceId: deviceId);
        },
      ),
      GoRoute(path: '/add-device', builder: (_, _) => const AddDeviceScreen()),
      GoRoute(
        path: '/provision-device',
        builder: (_, _) => const BleProvisioningScreen(),
      ),
      GoRoute(path: '/api-test', builder: (_, _) => const ApiTestScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Страница не найдена')),
      body: Center(child: Text(state.error?.toString() ?? 'Неизвестный адрес')),
    ),
  );
}

class _DeviceControlRoute extends StatelessWidget {
  const _DeviceControlRoute({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DeviceModel>>(
      future: DeviceService.getDevices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        DeviceModel? device;
        for (final item in snapshot.data ?? const <DeviceModel>[]) {
          if (item.id == deviceId) {
            device = item;
            break;
          }
        }

        if (device != null) return DeviceControlScreen(device: device);

        return Scaffold(
          appBar: AppBar(title: const Text('Устройство')),
          body: Center(
            child: Text(
              snapshot.hasError
                  ? 'Не удалось загрузить устройство'
                  : 'Устройство не найдено',
            ),
          ),
        );
      },
    );
  }
}
