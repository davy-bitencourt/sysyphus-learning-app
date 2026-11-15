import 'package:flutter_test/flutter_test.dart';
import 'package:sysyphus/l10n/strings.dart';
import 'package:sysyphus/styles/app_theme.dart';

void main() {
  test('Portuguese (Brazil) remains the default language', () {
    expect(AppSettings.instance.language.id, 'pt_BR');
    expect(currentLang(), 'pt');
    expect(appLocale().languageCode, 'pt');
    expect(appLocale().countryCode, 'BR');
  });

  test('Declared locales correspond to available translations', () {
    expect(kLangCodes, containsAll(<String>['pt', 'en']));
    expect(kSupportedLocales.map((locale) => locale.languageCode),
        containsAll(<String>['pt', 'en']));
  });
}
