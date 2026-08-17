import 'package:flutter/material.dart';
import 'package:sysyphus_learning_app/data/DAO/question_state_dao.dart';
import 'package:sysyphus_learning_app/data/DAO/template_dao.dart';
import 'package:sysyphus_learning_app/data/DAO/tag_dao.dart';
import 'package:sysyphus_learning_app/data/DAO/package_dao.dart';
import 'package:sysyphus_learning_app/data/DTO/question_dto.dart';
import 'package:sysyphus_learning_app/data/models/question_model.dart';
import 'templaate_edit_screen.dart';

class QuestionsEditScreen extends StatefulWidget {
  final Question? question; // null = criar nova
  final int? packageId; // pré-seleciona o pacote ao criar a partir de um deck

  const QuestionsEditScreen({super.key, this.question, this.packageId});

  @override
  State<QuestionsEditScreen> createState() => _QuestionsEditScreenState();
}

class _QuestionsEditScreenState extends State<QuestionsEditScreen> {
  final _statementController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _extraController = TextEditingController();
  final _suggestionController = TextEditingController();

  List<TextEditingController> _optionControllers = [];
  List<bool> _optionCorrect = [];

  List<TemplateModel> _templates = [];
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _packages = [];

  TemplateModel? _selectedTemplate;
  int? _selectedTagId;
  int? _selectedPackageId;

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
      _statementController.text = q.statement;
      _descriptionController.text = q.description;
      _extraController.text = q.extraComments;
      _suggestionController.text = q.suggestion ?? '';
      _selectedTagId = q.tagId;
      _selectedPackageId = q.packageId ?? widget.packageId;

      TemplateModel? match;
      for (final t in _templates) {
        if (t.id == q.templateId) {
          match = t;
          break;
        }
      }
      _selectedTemplate = match ?? (_templates.isNotEmpty ? _templates.first : null);
      _setupOptionControllers(initial: q.options);
    } else if (_templates.isNotEmpty) {
      _selectedTemplate = _templates.first;
      _setupOptionControllers();
    }

    if (mounted) setState(() => _loading = false);
  }

  void _setupOptionControllers({List<QuestionOption>? initial}) {
    final count = _selectedTemplate?.optionCount ?? 4;
    _optionControllers = List.generate(count, (i) {
      final controller = TextEditingController();
      if (initial != null && i < initial.length) {
        controller.text = initial[i].text;
      }
      return controller;
    });
    _optionCorrect = List.generate(count, (i) {
      if (initial != null && i < initial.length) return initial[i].correct;
      return false;
    });
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

  @override
  void dispose() {
    _statementController.dispose();
    _descriptionController.dispose();
    _extraController.dispose();
    _suggestionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
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
    if (_statementController.text.trim().isEmpty) {
      _showError('O enunciado não pode ficar vazio.');
      return;
    }

    setState(() => _saving = true);

    final options = List.generate(_optionControllers.length, (i) =>
      QuestionOption(text: _optionControllers[i].text.trim(), correct: _optionCorrect[i]));

    final question = Question(
      id: widget.question?.id,
      templateId: _selectedTemplate!.id,
      tagId: _selectedTagId,
      packageId: _selectedPackageId,
      statement: _statementController.text.trim(),
      type: _selectedTemplate!.type,
      options: options,
      suggestion: _suggestionController.text.trim(),
      extraComments: _extraController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    final dto = QuestionDto(
      packageId: question.packageId!,
      tagId: question.tagId,
      templateId: question.templateId!,
      enunciado: question.statement,
      questions: question.toQuestionsJson(),
      extra: question.extraComments,
      description: question.description,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Editar questão' : 'Nova questão',
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
      body: _templates.isEmpty ? _buildNoTemplates() : _buildForm(),
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
              'Nenhum template cadastrado ainda. Crie um template antes de adicionar questões.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openNewTemplate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
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
        _buildDropdown<int?>(
          label: 'Tag (opcional)',
          value: _selectedTagId,
          items: [
            const DropdownMenuItem(value: null, child: Text('Sem tag')),
            ..._tags.map((t) => DropdownMenuItem(value: t['id'] as int, child: Text(t['title'] as String))),
          ],
          onChanged: (v) => setState(() => _selectedTagId = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown<TemplateModel?>(
                label: 'Template',
                value: _selectedTemplate,
                items: _templates
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (t) => setState(() {
                  _selectedTemplate = t;
                  _setupOptionControllers();
                }),
              ),
            ),
            IconButton(
              onPressed: _openNewTemplate,
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFFE65100)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTextField(_statementController, 'Enunciado', maxLines: 3),
        const SizedBox(height: 16),
        _buildTextField(_descriptionController, 'Descrição (opcional)', maxLines: 2),
        const SizedBox(height: 16),
        _buildTextField(_extraController, 'Comentário extra (mostrado após responder)', maxLines: 2),
        const SizedBox(height: 20),
        _buildContentFields(),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_saving ? 'Salvando...' : 'Salvar questão',
              style: const TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildContentFields() {
    if (_selectedTemplate == null) return const SizedBox.shrink();

    if (_selectedTemplate!.type == QuestionType.open) {
      return _buildTextField(_suggestionController, 'Sugestão de resposta', maxLines: 3);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedTemplate!.type == QuestionType.multiple
              ? 'Alternativas (marque a correta)'
              : 'Afirmações (marque as verdadeiras)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 8),
        ...List.generate(_optionControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Checkbox(
                  value: _optionCorrect[i],
                  onChanged: (v) => setState(() => _optionCorrect[i] = v ?? false),
                  activeColor: const Color(0xFF2E7D32),
                ),
                Expanded(
                  child: TextField(
                    controller: _optionControllers[i],
                    decoration: InputDecoration(
                      hintText: 'Opção ${i + 1}',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
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
