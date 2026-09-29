import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final isRussian = settings.locale.languageCode == 'ru';
        return Scaffold(
          appBar: AppBar(title: Text(l10n.settings)),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              _SectionTitle(l10n.appearance),
              ListTile(
                leading: Icon(
                  settings.theme == AppTheme.emerald
                      ? Icons.eco_outlined
                      : settings.theme == AppTheme.indigo
                      ? Icons.bolt_outlined
                      : settings.theme == AppTheme.light
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                title: Text(l10n.appearance),
                trailing: DropdownButton<AppTheme>(
                  value: settings.theme,
                  onChanged: (theme) {
                    if (theme != null) settings.setTheme(theme);
                  },
                  items: [
                    for (final theme in AppTheme.values)
                      DropdownMenuItem(
                        value: theme,
                        child: Text(_themeLabel(l10n, theme)),
                      ),
                  ],
                ),
              ),
              const Divider(),
              _SectionTitle(l10n.language),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                trailing: DropdownButton<String>(
                  value: isRussian ? 'ru' : 'en',
                  onChanged: (languageCode) {
                    if (languageCode != null) {
                      settings.setLocale(Locale(languageCode));
                    }
                  },
                  items: [
                    DropdownMenuItem(value: 'ru', child: Text(l10n.russian)),
                    DropdownMenuItem(value: 'en', child: Text(l10n.english)),
                  ],
                ),
              ),
              const Divider(),
              _SectionTitle(l10n.account),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(l10n.signOut),
                subtitle: Text(l10n.signOutDescription),
                onTap: () => _confirmSignOut(context, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  String _themeLabel(AppLocalizations l10n, AppTheme theme) => switch (theme) {
    AppTheme.dark => l10n.darkTheme,
    AppTheme.light => l10n.lightTheme,
    AppTheme.emerald => l10n.emeraldTheme,
    AppTheme.indigo => l10n.indigoTheme,
  };

  Future<void> _confirmSignOut(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirmSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
