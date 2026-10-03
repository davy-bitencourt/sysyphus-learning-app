import 'package:flutter/material.dart';
import 'package:Sysyphus/styles/app_theme.dart';
import 'package:Sysyphus/data/DAO/template_dao.dart';
import 'package:Sysyphus/data/models/field_model.dart';

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
  bool _createdAny = false; // criou ao menos um template nesta tela (avisa quem abriu)

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.template?.name ?? '';
    _items = _buildItems(widget.template?.fields ?? const <FieldDefinition>[]);
  }

  /// Monta a lista reordenável: campos da pergunta, divisória, campos da resposta.
  /// Com lista vazia sobra só o enunciado (obrigatório) acima da divisória.
  List<Object> _buildItems(List<FieldDefinition> source) {
    final fields = TemplateModel.withStatement(source);
    final questionFields = fields.where((f) => f.section == FieldSection.question).toList();
    final answerFields = fields.where((f) => f.section == FieldSection.answer).toList();
    return [...questionFields, _divider, ...answerFields];
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

  Future<void> _editImageSize(FieldDefinition field) async {
    final limits = await showDialog<_ImageLimits>(
      context: context,
      builder: (_) => _ImageSizeDialog(
        initialWidth: field.maxWidth,
        initialHeight: field.maxHeight,
      ),
    );
    if (limits == null) return;
    final i = _items.indexOf(field);
    if (i < 0) return;
    setState(() {
      _items[i] = FieldDefinition(
        id: field.id,
        type: field.type,
        label: field.label,
        section: field.section,
        optionCount: field.optionCount,
        maxWidth: limits.width,
        maxHeight: limits.height,
      );
    });
  }

  String _imageLimitText(FieldDefinition f) {
    if (f.maxWidth != null && f.maxHeight != null) {
      return 'máx. ${_fmtLimit(f.maxWidth)} × ${_fmtLimit(f.maxHeight)} px';
    }
    if (f.maxWidth != null) return 'largura máx. ${_fmtLimit(f.maxWidth)} px';
    if (f.maxHeight != null) return 'altura máx. ${_fmtLimit(f.maxHeight)} px';
    return 'tamanho original';
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
      _snapGradableFieldsAboveDivider();
    });
  }

  /// Alternativas, V/F e o enunciado só fazem sentido antes de responder --
  /// se o usuário arrastar um desses campos pra baixo da divisória, ele volta
  /// pra cima automaticamente. (O enunciado pode ficar em qualquer posição
  /// acima da divisória.)
  void _snapGradableFieldsAboveDivider() {
    final dividerIndex = _dividerIndex;
    for (int i = _items.length - 1; i > dividerIndex; i--) {
      final item = _items[i];
      if (item is FieldDefinition && (item.isStatement || FieldType.isGradable(item.type))) {
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
          maxWidth: item.maxWidth,
          maxHeight: item.maxHeight,
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
        if (mounted) Navigator.pop(context, true);
      } else {
        await dao.insert(json);
        _createdAny = true;
        if (!mounted) return;
        // Continua na tela com tudo zerado, pronto para o próximo template.
        setState(() {
          _nameController.clear();
          _items = _buildItems(const <FieldDefinition>[]);
        });
        _showMessage('Template "${model.name}" salvo.');
      }
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

  void _showError(String message) => _showMessage(message);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Sai da tela devolvendo se algo foi criado. Limpa antes o SnackBar de
  /// "salvo": senão ele migra para o Scaffold da tela anterior (Home) no meio
  /// da transição de rota.
  void _leave() {
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.pop(context, _createdAny);
  }

  @override
  Widget build(BuildContext context) {
    // Voltar (seta ou gesto do sistema) devolve `true` se algum template foi
    // criado aqui, para a tela anterior recarregar a lista.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.text),
          onPressed: () => _leave(),
        ),
        title: Text(_isEditing ? 'Editar template' : 'Novo template',
          style: TextStyle(color: context.colors.text,
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
                icon: Icon(Icons.add, color: context.colors.accent),
                label: Text('Adicionar campo', style: TextStyle(color: context.colors.accent)),
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
          color: context.colors.bg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
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
      child: Divider(
        color: context.colors.border,
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(Icons.drag_indicator, color: Colors.grey[400]),
            ),
          ),
          Icon(_iconFor(field.type), color: context.colors.accent, size: context.icon(20)),
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
                          : field.type == FieldType.image
                              ? '${FieldType.label(field.type)} • ${_imageLimitText(field)}'
                              : FieldType.label(field.type),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (field.type == FieldType.image)
            IconButton(
              tooltip: 'Tamanho da imagem',
              icon: Icon(Icons.aspect_ratio_outlined, size: context.icon(18), color: Colors.grey[500]),
              onPressed: () => _editImageSize(field),
            ),
          if (!field.isStatement)
            IconButton(
              icon: Icon(Icons.delete_outline, size: context.icon(18), color: Color(0xFFC62828)),
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
  final _maxWidthController = TextEditingController();
  final _maxHeightController = TextEditingController();
  String _type = FieldType.text;
  int _optionCount = 4;

  @override
  void dispose() {
    _labelController.dispose();
    _maxWidthController.dispose();
    _maxHeightController.dispose();
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
      maxWidth: _type == FieldType.image ? _parseLimit(_maxWidthController.text) : null,
      maxHeight: _type == FieldType.image ? _parseLimit(_maxHeightController.text) : null,
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
          if (_type == FieldType.image) ...[
            const SizedBox(height: 12),
            Text('Tamanho máximo da imagem (opcional)',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _limitField(_maxWidthController, 'Largura (px)')),
                const SizedBox(width: 12),
                Expanded(child: _limitField(_maxHeightController, 'Altura (px)')),
              ],
            ),
          ],
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
                backgroundColor: context.colors.accent,
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


/// Limites de exibição de um campo de imagem (null = sem limite).
class _ImageLimits {
  final double? width;
  final double? height;
  const _ImageLimits(this.width, this.height);
}

/// Aceita vírgula ou ponto; vazio, zero ou inválido = sem limite.
double? _parseLimit(String text) {
  final v = double.tryParse(text.trim().replaceAll(',', '.'));
  return (v != null && v > 0) ? v : null;
}

String _fmtLimit(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

Widget _limitField(TextEditingController controller, String label) {
  return TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

class _ImageSizeDialog extends StatefulWidget {
  final double? initialWidth;
  final double? initialHeight;
  const _ImageSizeDialog({this.initialWidth, this.initialHeight});

  @override
  State<_ImageSizeDialog> createState() => _ImageSizeDialogState();
}

class _ImageSizeDialogState extends State<_ImageSizeDialog> {
  late final TextEditingController _width =
      TextEditingController(text: _fmtLimit(widget.initialWidth));
  late final TextEditingController _height =
      TextEditingController(text: _fmtLimit(widget.initialHeight));

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tamanho da imagem'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tamanho máximo de exibição, em pixels. A imagem é reduzida para '
            'caber, sem distorcer. Deixe em branco para não limitar.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          _limitField(_width, 'Largura máxima (px)'),
          const SizedBox(height: 12),
          _limitField(_height, 'Altura máxima (px)'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _ImageLimits(_parseLimit(_width.text), _parseLimit(_height.text)),
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
