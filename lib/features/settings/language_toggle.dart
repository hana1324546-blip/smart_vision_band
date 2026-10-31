import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({required this.isArabic, required this.onChanged, super.key});

  final bool isArabic;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return SwitchListTile(
      secondary: const Icon(Icons.translate),
      title: Text(strings.text('useArabic')),
      subtitle: Text(strings.text(isArabic ? 'arabicSelected' : 'englishSelected')),
      value: isArabic,
      onChanged: onChanged,
    );
  }
}