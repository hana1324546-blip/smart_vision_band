import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:smart_vision_band/l10n/app_localizations.dart';

void main() {
  test('provides English and Arabic settings labels', () {
    expect(AppLocalizations(const Locale('en')).text('settings'), 'Settings');
    expect(AppLocalizations(const Locale('ar')).text('settings'), 'الإعدادات');
  });
}