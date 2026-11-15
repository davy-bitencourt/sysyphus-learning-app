import '../DAO/template_dao.dart';
import '../models/field_model.dart';

/// Pré-configurações que usam o MESMO esquema de templates e questões do app.
/// Nenhuma tabela ou dado de questão existente é substituído ou migrado.
class QuickQuestionTemplates {
  static const choicesId = 'ux_quick_choices';
  static const truthId = 'ux_quick_truth';

  static const multipleChoice = TemplateModel(
    name: 'Múltipla escolha',
    fields: [
      FieldDefinition.statement,
      FieldDefinition(id: choicesId, type: FieldType.options,
          label: 'Alternativas', optionCount: 4),
    ],
  );

  // options (e não vof): o estudo trata as duas alternativas como seleção
  // única, sem reativar o tipo legado que foi descontinuado no editor.
  static const trueFalse = TemplateModel(
    name: 'Verdadeiro ou falso',
    fields: [
      FieldDefinition.statement,
      FieldDefinition(id: truthId, type: FieldType.options,
          label: 'Resposta', optionCount: 2),
    ],
  );

  static String? kindOf(TemplateModel template) {
    if (template.fields.length != 2) return null;
    final other = template.fields[1];
    if (other.type != FieldType.options) return null;
    if (other.id == choicesId && other.optionCount == 4) return 'multiple';
    if (other.id == truthId && other.optionCount == 2) return 'trueFalse';
    return null;
  }

  static Future<void> ensureExists(
    TemplateDao dao,
    List<TemplateModel> existing,
  ) async {
    for (final definition in [multipleChoice, trueFalse]) {
      final kind = kindOf(definition);
      if (existing.any((t) => kindOf(t) == kind)) continue;
      await dao.insert(definition.toJsonString());
    }
  }
}
