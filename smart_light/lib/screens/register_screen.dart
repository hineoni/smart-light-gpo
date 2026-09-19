import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _nameValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final name = (value ?? '').trim();
    if (name.isEmpty) return l10n.enterName;
    if (name.length < 2) return l10n.minimumTwoCharacters;
    return null;
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

  String? _confirmValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final password = value ?? '';
    if (password.isEmpty) return l10n.repeatPassword;
    if (password != _passCtrl.text) return l10n.passwordsDoNotMatch;
    return null;
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final success = await AuthService.register(
      _emailCtrl.text,
      _passCtrl.text,
      name: _nameCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!success) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.lastErrorMessage ?? l10n.registrationFailed,
          ),
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        actions: [
          const _ThemeToggleButton(),
          _RegisterLanguageMenu(),
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
                  l10n.createAccount,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.name,
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: _nameValidator,
                      ),
                      const SizedBox(height: 12),
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
                        textInputAction: TextInputAction.next,
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
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _hideConfirm,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.confirmPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hideConfirm = !_hideConfirm);
                            },
                            icon: Icon(
                              _hideConfirm
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: _confirmValidator,
                        onFieldSubmitted: (_) => _register(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : _register,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.register),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.alreadyHaveAccount),
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

class _RegisterLanguageMenu extends StatelessWidget {
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
