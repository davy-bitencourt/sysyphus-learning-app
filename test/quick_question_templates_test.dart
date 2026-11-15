import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sysyphus/data/models/field_model.dart';
import 'package:sysyphus/data/services/quick_question_templates.dart';
import 'package:sysyphus/data/services/simple_question_template.dart';

void main() {
  test('pré-configurações utilizam os campos do modelo SQLite atual', () {
    for (final template in [
      QuickQuestionTemplates.multipleChoice,
      QuickQuestionTemplates.trueFalse,
    ]) {
      final decoded = jsonDecode(template.toJsonString()) as Map<String, dynamic>;
      final reloaded = TemplateModel.fromMap(42, decoded);
      expect(reloaded.questionFields.first.id, FieldDefinition.statementId);
      expect(reloaded.questionFields.last.type, FieldType.options);
      expect(QuickQuestionTemplates.kindOf(reloaded), isNotNull);
      expect(SimpleQuestionTemplate.matches(reloaded), isFalse);
    }
  });

  test('múltipla escolha e verdadeiro ou falso possuem quantidades adequadas', () {
    expect(QuickQuestionTemplates.kindOf(QuickQuestionTemplates.multipleChoice), 'multiple');
    expect(QuickQuestionTemplates.multipleChoice.fields.last.optionCount, 4);
    expect(QuickQuestionTemplates.kindOf(QuickQuestionTemplates.trueFalse), 'trueFalse');
    expect(QuickQuestionTemplates.trueFalse.fields.last.optionCount, 2);
  });

  test('o modelo aberto original permanece compatível', () {
    expect(SimpleQuestionTemplate.matches(SimpleQuestionTemplate.definition), isTrue);
    expect(QuickQuestionTemplates.kindOf(SimpleQuestionTemplate.definition), isNull);
  });
}
