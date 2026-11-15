import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('novas mensagens de UX possuem traduções em quatro idiomas', () async {
    for (final lang in ['pt', 'en', 'es', 'ja']) {
      final raw = await rootBundle.loadString('lib/l10n/$lang.json');
      final entries = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      for (final key in [
        'ux.newSubject',
        'ux.create',
        'ux.createAndQuestion',
        'ux.questionType',
        'ux.optionValidation',
        'ux.commentOptional',
      ]) {
        expect(entries[key], isA<String>(), reason: '$lang: $key');
        expect((entries[key] as String).isNotEmpty, isTrue);
      }
    }
  });
}
