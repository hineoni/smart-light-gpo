import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  int _step = 0;
  String? _resetToken;
  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Введите email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Некорректный email';
    }
    return null;
  }

  String? _codeValidator(String? value) {
    if (!RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())) {
      return 'Введите 6-значный код';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if ((value ?? '').length < 6) return 'Минимум 6 символов';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    if (_step == 0) {
      final success = await AuthService.requestPasswordReset(_emailCtrl.text);
      if (!mounted) return;
      setState(() => _loading = false);
      if (success) {
        setState(() => _step = 1);
      } else {
        _showError();
      }
      return;
    }

    if (_step == 1) {
      final token = await AuthService.verifyPasswordResetCode(
        _emailCtrl.text,
        _codeCtrl.text,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (token != null) {
        setState(() {
          _resetToken = token;
          _step = 2;
        });
      } else {
        _showError();
      }
      return;
    }

    final success = await AuthService.completePasswordReset(
      _resetToken!,
      _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароль изменён. Войдите с новым паролем.')),
      );
      Navigator.pop(context);
    } else {
      _showError();
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AuthService.lastErrorMessage ?? 'Произошла ошибка')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Забыли пароль?',
      1 => 'Введите код',
      _ => 'Новый пароль',
    };

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _step == 0
                          ? Icons.lock_reset_outlined
                          : Icons.mark_email_read_outlined,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _step == 0
                          ? 'Введите почтовый адрес, и мы отправим код восстановления.'
                          : _step == 1
                          ? 'Код отправлен на ${_emailCtrl.text}'
                          : 'Придумайте новый пароль для аккаунта.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_step == 0)
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: _emailValidator,
                      ),
                    if (_step == 1)
                      TextFormField(
                        controller: _codeCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Код из письма',
                          prefixIcon: Icon(Icons.password_outlined),
                        ),
                        validator: _codeValidator,
                      ),
                    if (_step == 1 &&
                        AuthService.passwordResetVerificationCode != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        'Код для локального режима: ${AuthService.passwordResetVerificationCode}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_step == 2) ...[
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _hidePassword,
                        decoration: InputDecoration(
                          labelText: 'Новый пароль',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        validator: _passwordValidator,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _hideConfirm,
                        decoration: InputDecoration(
                          labelText: 'Повторите пароль',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                            icon: Icon(_hideConfirm ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                        validator: (value) => value != _passwordCtrl.text
                            ? 'Пароли не совпадают'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_step == 0 ? 'Отправить код' : _step == 1 ? 'Проверить код' : 'Изменить пароль'),
                      ),
                    ),
                    if (_step == 1)
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _step = 0),
                        child: const Text('Изменить email'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}