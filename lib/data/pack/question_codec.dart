import 'dart:convert';
import 'pack_models.dart';

/// ⚠ Único ponto que conhece o JSON da coluna question.questions.
/// Suposição: { "<id do campo>": valor }, onde valor é String (text/image/audio)
/// ou List<{text, correct}> (options). Se o seu formato for outro, ajuste só aqui.
class QuestionCodec {
  static String encode(TemplateDef tpl, Map<String, dynamic> valuesByLabel, Map<String, String> mediaMap) {
    final out = <String, dynamic>{};
    for (final f in tpl.fields) {
      final v = valuesByLabel[norm(f.label)];
      if (v == null || (v is String && v.isEmpty)) continue;
      if (f.type == FieldType.image || f.type == FieldType.audio) {
        out[f.id] = mediaMap[v] ?? v;
      } else {
        out[f.id] = v;
      }
    }
    return jsonEncode(out);
  }

  /// campo -> valor (somente os campos presentes)
  static Map<FieldDef, dynamic> decode(TemplateDef tpl, String json) {
    final out = <FieldDef, dynamic>{};
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      for (final f in tpl.fields) {
        if (m[f.id] != null) out[f] = m[f.id];
      }
    } catch (_) {}
    return out;
  }

  static String enunciado(TemplateDef tpl, String json) {
    for (final e in decode(tpl, json).entries) {
      if (norm(e.key.label) == 'enunciado') return norm(e.value.toString());
    }
    return '';
  }
}
