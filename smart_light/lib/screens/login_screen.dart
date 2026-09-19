import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import 'main_navigation_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _hidePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final email = (value ?? '').trim();
    if (email.isEmpty) return l10n.enterEmail;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return l10n.invalidEmail;
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final password = value ?? '';
    if (password.isEmpty) return l10n.enterPassword;
    if (password.length < 6) return l10n.minimumSixCharacters;
    return null;
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final success = await AuthService.login(_emailCtrl.text, _passCtrl.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!success) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.lastErrorMessage ?? l10n.invalidEmailOrPassword,
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  Future<void> _openRegister() async {
    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );

    if (!mounted || registered != true) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        actions: [
          const _ThemeToggleButton(),
          _LanguageMenu(),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 12),
                Text(
                  l10n.signInToAccount,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _hidePass,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePass = !_hidePass);
                            },
                            icon: Icon(
                              _hidePass
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: _passwordValidator,
                        onFieldSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.signIn),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _openRegister,
                        child: Text(l10n.noAccountRegister),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.language),
    onSelected: (code) => AppSettings.instance.setLocale(Locale(code)),
    itemBuilder: (context) => const [
      PopupMenuItem(value: 'ru', child: Text('Русский')),
      PopupMenuItem(value: 'en', child: Text('English')),
    ],
  );
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final isDark = AppSettings.instance.theme == AppTheme.dark;
        return IconButton(
          tooltip: isDark ? 'Use light theme' : 'Use dark theme',
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
          onPressed: () {
            AppSettings.instance.setTheme(
              isDark ? AppTheme.light : AppTheme.dark,
            );
          },
        );
      },
    );
  }
}
