import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:Sysyphus/styles/app_theme.dart';
import 'package:Sysyphus/data/DAO/question_state_dao.dart';
import 'package:Sysyphus/data/DAO/template_dao.dart';
import 'package:Sysyphus/data/DAO/tag_dao.dart';
import 'package:Sysyphus/data/DAO/package_dao.dart';
import 'package:Sysyphus/data/DTO/question_dto.dart';
import 'package:Sysyphus/data/models/field_model.dart';
import 'package:Sysyphus/data/models/question_model.dart';
import 'package:Sysyphus/data/services/media_storage_service.dart';
import 'templaate_edit_screen.dart';

class QuestionsEditScreen extends StatefulWidget {
  final Question? question; // null = criar nova
  final int? packageId; // pré-seleciona o pacote ao criar a partir de um deck

  const QuestionsEditScreen({super.key, this.question, this.packageId});

  @override
  State<QuestionsEditScreen> createState() => _QuestionsEditScreenState();
}

class _QuestionsEditScreenState extends State<QuestionsEditScreen> {
  Map<String, TextEditingController> _textControllers = {};
  Map<String, String?> _mediaPaths = {};
  Map<String, List<TextEditingController>> _optionControllers = {};
  Map<String, List<bool>> _optionCorrect = {};

  List<TemplateModel> _templates = [];
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _packages = [];

  TemplateModel? _selectedTemplate;
  int? _selectedTagId;
  int? _selectedPackageId;

  // Campo de tag em formato de texto com marcadores (#historia, #matematica...)
  // e autosugestão a partir das tags já cadastradas. O schema atual só
  // vincula UMA tag por questão, então usamos apenas o primeiro marcador
  // digitado ao salvar; se o app passar a suportar múltiplas tags por
  // questão, este é o ponto a estender.
  final TextEditingController _tagInputController = TextEditingController();
  String _tagQuery = '';

  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.question != null;

  @override
  void initState() {
    super.initState();
    _selectedPackageId = widget.packageId;
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final templateRows = await TemplateDao().getAll();
    final tagRows = await TagDao().getAll();
    final packageRows = await PackageDao().getAll();

    _templates = templateRows
        .map((row) => TemplateModel.fromJson(row['id'] as int, row['template'] as String))
        .toList();
    _tags = tagRows;
    _packages = packageRows;

    final q = widget.question;
    if (q != null) {
      _selectedTagId = q.tagId;
      _selectedPackageId = q.packageId ?? widget.packageId;

      if (_selectedTagId != null) {
        final match = _tags.firstWhere(
          (t) => t['id'] == _selectedTagId,
          orElse: () => const <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          _tagInputController.text = '#${match['title']} ';
        }
      }

      TemplateModel? match;
      for (final t in _templates) {
        if (t.id == q.templateId) {
          match = t;
          break;
        }
      }
      _selectedTemplate = match ?? (_templates.isNotEmpty ? _templates.first : null);
      if (_selectedTemplate != null) {
        _setupControllersForTemplate(_selectedTemplate!, initialValues: q.values);
      }
    } else if (_templates.isNotEmpty) {
      _selectedTemplate = _templates.first;
      _setupControllersForTemplate(_selectedTemplate!);
    }

    if (mounted) setState(() => _loading = false);
  }

  void _setupControllersForTemplate(TemplateModel template, {Map<String, dynamic>? initialValues}) {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    for (final list in _optionControllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }

    _textControllers = {};
    _mediaPaths = {};
    _optionControllers = {};
    _optionCorrect = {};

    for (final field in template.fields) {
      final raw = initialValues?[field.id];
      switch (field.type) {
        case FieldType.text:
          _textControllers[field.id] = TextEditingController(text: raw?.toString() ?? '');
          break;
        case FieldType.image:
        case FieldType.audio:
          _mediaPaths[field.id] = raw as String?;
          break;
        case FieldType.options:
        case FieldType.vof:
          final options = (raw as List?)
                  ?.map((o) => OptionValue.fromMap(o as Map<String, dynamic>))
                  .toList() ??
              const <OptionValue>[];
          _optionControllers[field.id] = List.generate(field.optionCount, (i) =>
            TextEditingController(text: i < options.length ? options[i].text : ''));
          _optionCorrect[field.id] = List.generate(field.optionCount, (i) =>
            i < options.length ? options[i].correct : false);
          break;
      }
    }
  }

  Future<void> _openNewTemplate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
    );
    if (result == true) {
      setState(() => _loading = true);
      await _loadOptions();
    }
  }

  Future<void> _pickImage(String fieldId, {required bool fromCamera}) async {
    final path = await MediaStorageService.pickImage(fromCamera: fromCamera);
    if (path != null) setState(() => _mediaPaths[fieldId] = path);
  }

  Future<void> _pickAudio(String fieldId) async {
    final path = await MediaStorageService.pickAudio();
    if (path != null) setState(() => _mediaPaths[fieldId] = path);
  }

  void _clearMedia(String fieldId) => setState(() => _mediaPaths[fieldId] = null);

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    for (final list in _optionControllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    _tagInputController.dispose();
    super.dispose();
  }

  void _onTagInputChanged(String text) {
    final hashIndex = text.lastIndexOf('#');
    final query = hashIndex == -1 ? '' : text.substring(hashIndex + 1).trim();
    setState(() => _tagQuery = query);
  }

  void _selectSuggestedTag(int id, String title) {
    setState(() {
      _selectedTagId = id;
      _tagInputController.text = '#$title ';
      _tagInputController.selection = TextSelection.collapsed(offset: _tagInputController.text.length);
      _tagQuery = '';
    });
  }

  /// Resolve o id da tag a partir do texto digitado (primeiro marcador
  /// #algo). Se a tag ainda não existe, cria e recarrega a lista para
  /// obter o id gerado.
  Future<int?> _resolveTagId() async {
    final text = _tagInputController.text.trim();
    if (text.isEmpty) return null;

    final hashIndex = text.indexOf('#');
    final raw = hashIndex != -1 ? text.substring(hashIndex + 1) : text;
    final tagName = raw.split(RegExp(r'\s')).first.trim();
    if (tagName.isEmpty) return null;

    for (final t in _tags) {
      if ((t['title'] as String).toLowerCase() == tagName.toLowerCase()) {
        return t['id'] as int;
      }
    }

    await TagDao().insert(tagName);
    final refreshed = await TagDao().getAll();
    _tags = refreshed;
    for (final t in refreshed) {
      if ((t['title'] as String).toLowerCase() == tagName.toLowerCase()) {
        return t['id'] as int;
      }
    }
    return null;
  }

  Map<String, dynamic> _collectValues(TemplateModel template) {
    final values = <String, dynamic>{};
    for (final field in template.fields) {
      switch (field.type) {
        case FieldType.text:
          values[field.id] = _textControllers[field.id]?.text.trim() ?? '';
          break;
        case FieldType.image:
        case FieldType.audio:
          values[field.id] = _mediaPaths[field.id];
          break;
        case FieldType.options:
        case FieldType.vof:
          final controllers = _optionControllers[field.id] ?? [];
          final corrects = _optionCorrect[field.id] ?? [];
          values[field.id] = List.generate(controllers.length, (i) =>
            OptionValue(text: controllers[i].text.trim(), correct: corrects[i]).toMap());
          break;
      }
    }
    return values;
  }

  Future<void> _save() async {
    if (_selectedTemplate == null || _selectedTemplate!.id == null) {
      _showError('Escolha um template antes de salvar.');
      return;
    }
    if (_selectedPackageId == null) {
      _showError('Escolha um pacote antes de salvar.');
      return;
    }

    final statementText =
        _textControllers[FieldDefinition.statementId]?.text.trim() ?? '';
    if (statementText.isEmpty) {
      _showError('Preencha o enunciado antes de salvar.');
      return;
    }

    setState(() => _saving = true);

    final values = _collectValues(_selectedTemplate!);
    final tagId = await _resolveTagId();

    final dto = QuestionDto(
      packageId: _selectedPackageId!,
      tagId: tagId,
      templateId: _selectedTemplate!.id!,
      questions: jsonEncode(values),
    );

    final dao = QuestionDao();
    try {
      if (_isEditing) {
        await dao.updateQuestion(widget.question!.id!, dto);
      } else {
        await dao.insert(dto);
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
      await QuestionDao().delete(widget.question!.id!);
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Editar questão' : 'Nova questão',
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
      body: _templates.isEmpty ? _buildNoTemplates() : _buildForm(),
      // O botão de salvar fica fixo ao final da tela, acima da área de
      // navegação do sistema; o formulário acima dele permanece rolável
      // para o caso de o template ter muitos campos.
      bottomNavigationBar: _templates.isEmpty ? null : _buildSaveFooter(),
    );
  }

  Widget _buildSaveFooter() {
    return SafeArea(
      top: false,
      child: Container(
        color: context.colors.bg,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
            child: Text(_saving ? 'Salvando...' : 'Salvar questão',
              style: const TextStyle(fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _buildNoTemplates() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nenhum template cadastrado ainda. Crie um template (com os campos que quiser: texto, imagem, áudio, alternativas...) antes de adicionar questões.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openNewTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Criar template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final template = _selectedTemplate;
    final questionFields = template?.questionFields ?? const [];
    final answerFields = template?.answerFields ?? const [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDropdown<int?>(
          label: 'Pacote',
          value: _selectedPackageId,
          items: _packages
              .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['title'] as String)))
              .toList(),
          onChanged: (v) => setState(() => _selectedPackageId = v),
        ),
        const SizedBox(height: 16),
        _buildTagField(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown<TemplateModel?>(
                label: 'Template',
                value: _selectedTemplate,
                items: _templates
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (t) {
                  if (t == null) return;
                  setState(() {
                    _selectedTemplate = t;
                    _setupControllersForTemplate(t);
                  });
                },
              ),
            ),
            IconButton(
              onPressed: _openNewTemplate,
              icon: Icon(Icons.add_circle_outline, color: context.colors.accent),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (template != null) ...[
          // Lista de campos antes de responder
          ...questionFields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildFieldInput(f),
              )),

          if (answerFields.isNotEmpty) ...[
            // Divisor contínuo/único
            Divider(
              color: context.colors.border, 
              thickness: 1.5,
              height: 1.5,
            ),
            
            // Espaçamento uniforme após a linha
            const SizedBox(height: 20),

            // Lista de campos depois de responder
            ...answerFields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildFieldInput(f),
                )),
          ],
        ],
        // Espaço extra para a última seção não ficar colada no rodapé fixo.
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTagField() {
    final query = _tagQuery.toLowerCase();
    final matches = query.isEmpty
        ? const <Map<String, dynamic>>[]
        : _tags.where((t) => (t['title'] as String).toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tag (opcional)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.text)),
        const SizedBox(height: 8),
        TextField(
          controller: _tagInputController,
          minLines: 1,
          maxLines: null, // expande verticalmente conforme o texto cresce
          onChanged: _onTagInputChanged,
          decoration: InputDecoration(
            hintText: '#historia #matematica',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: matches.map((t) => ActionChip(
              label: Text('#${t['title']}'),
              backgroundColor: context.colors.accent.withValues(alpha: 0.15),
              side: BorderSide.none,
              onPressed: () => _selectSuggestedTag(t['id'] as int, t['title'] as String),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldInput(FieldDefinition field) {
    switch (field.type) {
      case FieldType.text:
        return _buildTextField(
          _textControllers[field.id]!,
          field.isStatement ? '${field.label} *' : field.label,
          maxLines: 3,
        );
      case FieldType.image:
        return _buildMediaField(field, isImage: true);
      case FieldType.audio:
        return _buildMediaField(field, isImage: false);
      case FieldType.options:
      case FieldType.vof:
        return _buildOptionsField(field);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMediaField(FieldDefinition field, {required bool isImage}) {
    final path = _mediaPaths[field.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.text)),
        const SizedBox(height: 8),
        if (path != null) ...[
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(path), height: 140, fit: BoxFit.cover, width: double.infinity),
            )
          else
            Row(children: [
              Icon(Icons.audiotrack, color: context.colors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis)),
            ]),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 4,
          children: [
            if (isImage) ...[
              TextButton.icon(
                onPressed: () => _pickImage(field.id, fromCamera: false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeria'),
              ),
              TextButton.icon(
                onPressed: () => _pickImage(field.id, fromCamera: true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Câmera'),
              ),
            ] else
              TextButton.icon(
                onPressed: () => _pickAudio(field.id),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Escolher áudio'),
              ),
            if (path != null)
              IconButton(
                onPressed: () => _clearMedia(field.id),
                icon: const Icon(Icons.close, color: Color(0xFFC62828)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionsField(FieldDefinition field) {
    final controllers = _optionControllers[field.id] ?? [];
    final corrects = _optionCorrect[field.id] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.type == FieldType.options
              ? '${field.label} (marque a correta; mais de uma = seleção múltipla)'
              : '${field.label} (marque as verdadeiras)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.text),
        ),
        const SizedBox(height: 8),
        ...List.generate(controllers.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Checkbox(
                value: corrects[i],
                onChanged: (v) => setState(() => _optionCorrect[field.id]![i] = v ?? false),
                activeColor: const Color(0xFF2E7D32),
              ),
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  decoration: InputDecoration(
                    hintText: 'Opção ${i + 1}',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
