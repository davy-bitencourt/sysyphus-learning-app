import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../styles/app_theme.dart';

typedef Tr = String Function(String key, [Map<String, Object> args]);

const List<String> kLangCodes = ['en', 'pt'];

String currentLang() {
  final l = AppSettings.instance.language;
  final k = '${l.id} ${l.name}'.toLowerCase();
  for (final code in kLangCodes) {
    if (k.startsWith(code) || k.contains('${code}_') || k.contains('${code}-')) return code;
  }
  if (k.contains('port')) return 'pt';
  return 'en';
}

Locale appLocale() => currentLang() == 'pt' ? const Locale('pt', 'BR') : Locale(currentLang());

const List<Locale> kSupportedLocales = [Locale('en'), Locale('pt', 'BR')];

final Map<String, Map<String, String>> _strings = {};

Future<void> loadStrings() async {
  for (final code in kLangCodes) {
    final raw = await rootBundle.loadString('lib/l10n/$code.json');
    _strings[code] = Map<String, String>.from(jsonDecode(raw) as Map);
  }
}

String _lookup(String lang, String key, Map<String, Object> args) {
  var text = _strings[lang]?[key] ?? _strings['en']?[key] ?? key;
  args.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
  return text;
}

String trg(String key, [Map<String, Object> args = const {}]) =>
    _lookup(currentLang(), key, args);

extension TrX on BuildContext {
  String tr(String key, [Map<String, Object> args = const {}]) {
    final code = Localizations.localeOf(this).languageCode;
    final lang = kLangCodes.contains(code) ? code : 'en';
    return _lookup(lang, key, args);
  }
}

List<String> monthAbbr() => currentLang() == 'pt'
    ? const ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez']
    : const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

List<String> weekdayAbbr() => currentLang() == 'pt'
    ? const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
    : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

List<String> weekdayFull() => currentLang() == 'pt'
    ? const ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo']
    : const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
