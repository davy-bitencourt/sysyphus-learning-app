import '../DAO/template_dao.dart';
import '../models/field_model.dart';

/// Modelo básico, compatível com o JSON de templates do Sysyphus.
class SimpleQuestionTemplate {
  static const answerId = 'simple_answer';

  static const _answer = FieldDefinition(
    id: answerId,
    type: FieldType.text,
    label: 'Resposta',
    section: FieldSection.answer,
  );

  static const definition = TemplateModel(
    name: 'Pergunta e resposta',
    fields: [FieldDefinition.statement, _answer],
  );

  static bool matches(TemplateModel template) {
    final fields = template.fields;
    return fields.length == 2 &&
        fields[0].isStatement &&
        fields[1].id == answerId &&
        fields[1].type == FieldType.text &&
        fields[1].section == FieldSection.answer;
  }

  /// Não cria um modelo novo se um equivalente já estiver cadastrado.
  static Future<int> ensureExists(
    TemplateDao dao,
    List<TemplateModel> existing,
  ) async {
    for (final template in existing) {
      if (matches(template) && template.id != null) return template.id!;
    }
    return dao.insert(definition.toJsonString());
  }
}
