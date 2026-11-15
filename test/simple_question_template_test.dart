import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sysyphus/data/models/field_model.dart';
import 'package:sysyphus/data/services/simple_question_template.dart';

void main() {
  test('modelo simples possui enunciado e resposta', () {
    final template = SimpleQuestionTemplate.definition;
    expect(SimpleQuestionTemplate.matches(template), isTrue);
    expect(template.questionFields.single.id, FieldDefinition.statementId);
    expect(template.answerFields.single.id, SimpleQuestionTemplate.answerId);
    expect(template.answerFields.single.type, FieldType.text);
  });

  test('modelo simples preserva o formato JSON já existente', () {
    final serialized = SimpleQuestionTemplate.definition.toJsonString();
    final json = jsonDecode(serialized) as Map<String, dynamic>;
    final restored = TemplateModel.fromMap(100, json);
    expect(SimpleQuestionTemplate.matches(restored), isTrue);
    expect(restored.id, 100);
    expect(restored.fields, hasLength(2));
  });

  test('modelo personalizado não é interpretado como básico', () {
    final custom = TemplateModel(
      id: 5,
      name: 'Alternativas',
      fields: [
        FieldDefinition.statement,
        const FieldDefinition(
          id: 'choices', type: FieldType.options, label: 'Alternativas',
        ),
      ],
    );
    expect(SimpleQuestionTemplate.matches(custom), isFalse);
  });
}
