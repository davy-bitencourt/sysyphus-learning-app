import 'package:flutter/material.dart';
import 'package:sysyphus_learning_app/data/DAO/template_dao.dart';
import 'package:sysyphus_learning_app/data/models/field_model.dart';

/// Marcador que representa a linha divisória dentro da lista reordenável.
/// Tudo que fica ANTES dela na lista vira `section: question`, tudo que
/// fica DEPOIS vira `section: answer`.
class _DividerMarker {
  const _DividerMarker();
}

const _divider = _DividerMarker();

class TemplateEditScreen extends StatefulWidget {
  final TemplateModel? template; // null = criar novo

  const TemplateEditScreen({super.key, this.template});

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  final _nameController = TextEditingController();
  late List<Object> _items; // FieldDefinition ou _DividerMarker, nessa ordem
  bool _saving = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.template?.name ?? '';

    final fields = TemplateModel.withStatement(
      widget.template?.fields ?? const <FieldDefinition>[],
    );
    final questionFields = fields.where((f) => f.section == FieldSection.question).toList();
    final answerFields = fields.where((f) => f.section == FieldSection.answer).toList();
    _items = [...questionFields, _divider, ...answerFields];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _dividerIndex => _items.indexOf(_divider);

  Future<void> _addField() async {
    final field = await showModalBottomSheet<FieldDefinition>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddFieldSheet(),
    );
    if (field == null) return;
    setState(() {
      _items.insert(_dividerIndex, field); // sempre entra logo acima da divisória
    });
  }

  void _removeField(FieldDefinition field) {
    if (field.isStatement) return; // enunciado é obrigatório
    setState(() => _items.remove(field));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _pinStatementFirst();
      _snapGradableFieldsAboveDivider();
    });
  }

  /// Se alguém soltar outro campo acima do enunciado, ele volta pro topo.
  void _pinStatementFirst() {
    final i = _items.indexWhere((e) => e is FieldDefinition && e.isStatement);
    if (i > 0) {
      final statement = _items.removeAt(i);
      _items.insert(0, statement);
    }
  }

  /// Alternativas e V/F só fazem sentido antes de responder -- se o
  /// usuário arrastar um desses campos pra baixo da divisória, ele volta
  /// pra cima automaticamente.
  void _snapGradableFieldsAboveDivider() {
    final dividerIndex = _dividerIndex;
    for (int i = _items.length - 1; i > dividerIndex; i--) {
      final item = _items[i];
      if (item is FieldDefinition && FieldType.isGradable(item.type)) {
        _items.removeAt(i);
        _items.insert(_dividerIndex, item);
      }
    }
  }

  List<FieldDefinition> _computeFields() {
    final dividerIndex = _dividerIndex;
    final result = <FieldDefinition>[];
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item is FieldDefinition) {
        final section = i < dividerIndex ? FieldSection.question : FieldSection.answer;
        result.add(FieldDefinition(
          id: item.id,
          type: item.type,
          label: item.label,
          section: section,
          optionCount: item.optionCount,
        ));
      }
    }
    return result;
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Dê um nome ao template.');
      return;
    }
    final fields = _computeFields();
    if (fields.length < 2) {
      _showError('Adicione pelo menos um campo além do enunciado.');
      return;
    }

    setState(() => _saving = true);
    final model = TemplateModel(name: _nameController.text.trim(), fields: fields);
    final json = model.toJsonString();

    try {
      final dao = TemplateDao();
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome do template',
                hintText: 'Ex: Questão com imagem e múltipla escolha',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addField,
                icon: const Icon(Icons.add, color: Color(0xFFE65100)),
                label: const Text('Adicionar campo', style: TextStyle(color: Color(0xFFE65100))),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              buildDefaultDragHandles: false,
              onReorder: _onReorder,
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                if (item is _DividerMarker) {
                  return _buildDividerRow(key: const ValueKey('__divider__'));
                }
                final field = item as FieldDefinition;
                return _buildFieldTile(field, i, key: ValueKey(field.id));
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_saving ? 'Salvando...' : 'Salvar template', style: const TextStyle(fontSize: 15)),
            ),
          ),
        ),
      ),
    );
  }

Widget _buildDividerRow({required Key key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: const Divider(
        color: Color(0xFFE0E0E0),
        thickness: 1.5,
        height: 1.5,
      ),
    );
  }

  Widget _buildFieldTile(FieldDefinition field, int index, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          field.isStatement
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(Icons.lock_outline, color: Colors.grey[400]),
                )
              : ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(Icons.drag_indicator, color: Colors.grey[400]),
                  ),
                ),
          Icon(_iconFor(field.type), color: const Color(0xFFE65100), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  field.isStatement
                      ? 'Texto • obrigatório'
                      : FieldType.needsOptionCount(field.type)
                          ? '${FieldType.label(field.type)} • ${field.optionCount} opções'
                          : FieldType.label(field.type),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (!field.isStatement)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFC62828)),
              onPressed: () => _removeField(field),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case FieldType.image: return Icons.image_outlined;
      case FieldType.audio: return Icons.audiotrack_outlined;
      case FieldType.options: return Icons.rule_outlined;
      case FieldType.vof: return Icons.rule_outlined;
      default: return Icons.short_text_outlined;
    }
  }
}

class _AddFieldSheet extends StatefulWidget {
  const _AddFieldSheet();

  @override
  State<_AddFieldSheet> createState() => _AddFieldSheetState();
}

class _AddFieldSheetState extends State<_AddFieldSheet> {
  final _labelController = TextEditingController();
  String _type = FieldType.text;
  int _optionCount = 4;

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_labelController.text.trim().isEmpty) return;
    Navigator.pop(context, FieldDefinition(
      id: 'field_${DateTime.now().microsecondsSinceEpoch}',
      type: _type,
      label: _labelController.text.trim(),
      section: FieldSection.question, // entra acima da divisória; arraste pra mudar
      optionCount: _optionCount,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: 
    Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novo campo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'Rótulo do campo',
              hintText: 'Ex: Imagem do enunciado',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            items: FieldType.all
                .map((t) => DropdownMenuItem(value: t, child: Text(FieldType.label(t))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? FieldType.text),
            decoration: InputDecoration(
              labelText: 'Tipo de campo',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (FieldType.needsOptionCount(_type)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Quantidade de opções:'),
                IconButton(
                  onPressed: _optionCount > 2 ? () => setState(() => _optionCount--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_optionCount'),
                IconButton(
                  onPressed: _optionCount < 8 ? () => setState(() => _optionCount++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
              ),
              child: const Text('Adicionar'),
            ),
          ),
        ],
      ),
      ), 
    );
  }
}
