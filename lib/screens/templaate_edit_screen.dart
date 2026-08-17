import 'package:flutter/material.dart';
import 'package:sysyphus_learning_app/data/DAO/template_dao.dart';
import 'package:sysyphus_learning_app/data/models/question_model.dart';

class TemplateEditScreen extends StatefulWidget {
  final TemplateModel? template; // null = criar novo

  const TemplateEditScreen({super.key, this.template});

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late QuestionType _type;
  late int _optionCount;
  bool _saving = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    _type = widget.template?.type ?? QuestionType.multiple;
    _optionCount = widget.template?.optionCount ?? 4;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dao = TemplateDao();
    final model = TemplateModel(type: _type, optionCount: _optionCount);
    final json = model.toJsonString();

    try {
      if (_isEditing) {
        await dao.update(widget.template!.id!, json);
      } else {
        await dao.insert(json);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    setState(() => _saving = true);
    try {
      await TemplateDao().delete(widget.template!.id!);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsOptionCount = _type != QuestionType.open;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Editar template' : 'Novo template',
          style: const TextStyle(color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Tipo de questão',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          _buildTypeOption(QuestionType.open, 'Aberta',
            'Resposta livre, com sugestão de gabarito.'),
          _buildTypeOption(QuestionType.multiple, 'Múltipla escolha',
            'Uma alternativa correta entre várias.'),
          _buildTypeOption(QuestionType.vof, 'Verdadeiro ou Falso',
            'Uma ou mais afirmações a classificar.'),

          if (needsOptionCount) ...[
            const SizedBox(height: 24),
            const Text('Quantidade de opções',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E))),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _optionCount > 2
                      ? () => setState(() => _optionCount--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_optionCount', style: const TextStyle(fontSize: 16)),
                IconButton(
                  onPressed: _optionCount < 8
                      ? () => setState(() => _optionCount++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_saving ? 'Salvando...' : 'Salvar template',
                style: const TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(QuestionType type, String title, String subtitle) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE65100).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFE65100) : const Color(0xFFE0E0E0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFFE65100) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
