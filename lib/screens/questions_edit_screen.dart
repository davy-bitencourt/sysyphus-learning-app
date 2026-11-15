import 'dart:convert';
import 'package:path/path.dart' as p;
import '../widgets/media_image.dart';
import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../styles/app_theme.dart';
import '../data/DAO/question_state_dao.dart';
import '../data/DAO/template_dao.dart';
import '../data/DAO/tag_dao.dart';
import '../data/DAO/package_dao.dart';
import '../data/DTO/question_dto.dart';
import '../data/models/field_model.dart';
import '../data/models/question_model.dart';
import '../data/services/order_service.dart';
import '../data/services/media_storage_service.dart';
import '../data/services/simple_question_template.dart';
import '../data/services/quick_question_templates.dart';
import '../widgets/quick_subject_dialog.dart';
import 'templaate_edit_screen.dart';
import '../widgets/markdown_text.dart';

class TagTextEditingController extends TextEditingController {
  TextStyle tagStyle;

  TagTextEditingController({super.text, required this.tagStyle});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> children = [];
    final RegExp regExp = RegExp(r'(#[^\s]+(?:\s+|$))|([^#]+)');

    text.splitMapJoin(
      regExp,
      onMatch: (Match match) {
        final String matchText = match[0]!;
        if (matchText.startsWith('#')) {
          children.add(TextSpan(text: matchText, style: tagStyle));
        } else {
          children.add(TextSpan(text: matchText, style: style));
        }
        return matchText;
      },
      onNonMatch: (String nonMatch) {
        children.add(TextSpan(text: nonMatch, style: style));
        return nonMatch;
      },
    );

    return TextSpan(style: style, children: children);
  }
}

class QuestionsEditScreen extends StatefulWidget {
  final Question? question;
  final int? packageId;

  const QuestionsEditScreen({super.key, this.question, this.packageId});

  @override
  State<QuestionsEditScreen> createState() => _QuestionsEditScreenState();
}

class _QuestionsEditScreenState extends State<QuestionsEditScreen> {
  Map<String, TextEditingController> _textControllers = {};
  Map<String, String?> _mediaPaths = {};
  Map<String, List<TextEditingController>> _optionControllers = {};
  Map<String, List<bool>> _optionCorrect = {};

  final Set<String> _previewing = {};

  final Map<String, dynamic> _buffer = {};

  List<TemplateModel> _templates = [];
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _packages = [];

  TemplateModel? _selectedTemplate;
  int? _selectedPackageId;

  late final TagTextEditingController _tagInputController;
  String _tagQuery = '';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _createdAny = false;
  bool _showAdvanced = false;
  bool _leaving = false;
  String _initialSnapshot = '';

  bool get _isEditing => widget.question != null;

  @override
  void initState() {
    super.initState();
    _selectedPackageId = widget.packageId;
    _tagInputController = TagTextEditingController(
      tagStyle: const TextStyle(fontWeight: FontWeight.bold),
    );
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final templateDao = TemplateDao();
    var templateRows = await OrderService.apply(
      OrderService.templatesKey,
      await templateDao.getAll(),
      (t) => t['id'] as int,
    );
    final tagRows = await TagDao().getAll();
    final packageRows = await OrderService.apply(
      OrderService.packagesKey,
      await PackageDao().getAll(),
      (p) => p['id'] as int,
    );

    _templates = templateRows
        .map((row) => TemplateModel.fromJson(row['id'] as int, row['template'] as String))
        .toList();
    if (!_isEditing) {
      final basicId = await SimpleQuestionTemplate.ensureExists(templateDao, _templates);
      await QuickQuestionTemplates.ensureExists(templateDao, _templates);
      // Recarrega sempre: os modelos de múltipla escolha e V/F podem ter sido
      // inseridos sem alterar os modelos/questões já existentes.
      templateRows = await OrderService.apply(
        OrderService.templatesKey,
        await templateDao.getAll(),
        (t) => t['id'] as int,
      );
      _templates = templateRows
          .map((row) => TemplateModel.fromJson(row['id'] as int, row['template'] as String))
          .toList();
      _selectedTemplate = _templates.firstWhere((t) => t.id == basicId);
    }
    _tags = tagRows;
    _packages = packageRows;
    if (_selectedPackageId == null && _packages.isNotEmpty) {
      _selectedPackageId = _packages.first['id'] as int;
    }

    final q = widget.question;
    if (q != null) {
      _commentController.text = q.values['ux_comment'] as String? ?? '';
      _selectedPackageId = q.packageId ?? widget.packageId ?? _selectedPackageId;
      if (q.tagId != null) {
        final match = _tags.firstWhere(
          (t) => t['id'] == q.tagId,
          orElse: () => const <String, dynamic>{},
        );
        if (match.isNotEmpty) _tagInputController.text = '#${match['title']} ';
      }
      for (final t in _templates) {
        if (t.id == q.templateId) {
          _selectedTemplate = t;
          break;
        }
      }
      _selectedTemplate ??= _templates.isNotEmpty ? _templates.first : null;
      _showAdvanced = _selectedTemplate != null &&
          !SimpleQuestionTemplate.matches(_selectedTemplate!) &&
          QuickQuestionTemplates.kindOf(_selectedTemplate!) == null;
      if (_selectedTemplate != null) {
        _setupControllersForTemplate(
          _selectedTemplate!,
          initialValues: {...q.values, ..._bufferValuesFor(_selectedTemplate!)},
        );
      }
    } else if (_selectedTemplate != null) {
      _setupControllersForTemplate(
        _selectedTemplate!,
        initialValues: _bufferValuesFor(_selectedTemplate!),
      );
    }

    _initialSnapshot = _formSnapshot();
    if (mounted) setState(() => _loading = false);
  }

  String _formSnapshot() => jsonEncode({
    'template': _selectedTemplate?.id,
    'package': _selectedPackageId,
    'tag': _tagInputController.text,
    'comment': _commentController.text,
    'values': _selectedTemplate == null
        ? <String, dynamic>{} : _collectValues(_selectedTemplate!),
    'buffer': _buffer,
  });

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
    _previewing.clear();

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
          _optionControllers[field.id] = List.generate(
              field.optionCount, (i) => TextEditingController(text: i < options.length ? options[i].text : ''));
          if (field.id == QuickQuestionTemplates.truthId && options.isEmpty) {
            _optionControllers[field.id]![0].text = trg('ux.trueLabel');
            _optionControllers[field.id]![1].text = trg('ux.falseLabel');
          }
          _optionCorrect[field.id] =
              List.generate(field.optionCount, (i) => i < options.length ? options[i].correct : false);
          break;
      }
    }
  }

  String _bufferKey(FieldDefinition f) => '${f.type}:${f.id}';

  void _saveToBuffer(TemplateModel template) {
    final values = _collectValues(template);
    for (final f in template.fields) {
      _buffer[_bufferKey(f)] = values[f.id];
    }
  }

  Map<String, dynamic> _bufferValuesFor(TemplateModel template) => {
        for (final f in template.fields)
          if (_buffer.containsKey(_bufferKey(f))) f.id: _buffer[_bufferKey(f)],
      };

  Future<void> _openNewPackage() async {
    final created = await showQuickSubjectDialog(context, allowAddQuestion: false);
    if (created == null || !mounted) return;
    final rows = await OrderService.apply(
        OrderService.packagesKey, await PackageDao().getAll(), (p) => p['id'] as int);
    if (!mounted) return;
    setState(() {
      _packages = rows;
      _selectedPackageId = created.id;
    });
  }

  Future<void> _openNewTemplate() async {
    final previousIds = _templates.map((template) => template.id).toSet();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
    );
    if (result == true) {
      if (_selectedTemplate != null) _saveToBuffer(_selectedTemplate!);
      setState(() => _loading = true);
      await _loadOptions();
      if (!mounted) return;
      final added = _templates.where((template) => !previousIds.contains(template.id));
      if (added.isEmpty) return;
      setState(() {
        _selectedTemplate = added.last;
        _showAdvanced = true;
        _setupControllersForTemplate(
          _selectedTemplate!, initialValues: _bufferValuesFor(_selectedTemplate!));
      });
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
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _buffer.clear();
    _previewing.clear();
    for (final c in _textControllers.values) {
      c.clear();
    }
    for (final id in _mediaPaths.keys.toList()) {
      _mediaPaths[id] = null;
    }
    for (final list in _optionControllers.values) {
      for (final c in list) {
        c.clear();
      }
    }
    final trueFalseInputs = _optionControllers[QuickQuestionTemplates.truthId];
    if (trueFalseInputs != null && trueFalseInputs.length >= 2) {
      trueFalseInputs[0].text = trg('ux.trueLabel');
      trueFalseInputs[1].text = trg('ux.falseLabel');
    }
    for (final list in _optionCorrect.values) {
      for (var i = 0; i < list.length; i++) {
        list[i] = false;
      }
    }
    _tagInputController.clear();
    _commentController.clear();
    _tagQuery = '';
  }

  void _onTagInputChanged(String text) {
    final hashIndex = text.lastIndexOf('#');
    final query = hashIndex == -1 ? '' : text.substring(hashIndex + 1).trim();
    setState(() => _tagQuery = query);
  }

  void _selectSuggestedTag(String title) {
    final currentText = _tagInputController.text;
    final hashIndex = currentText.lastIndexOf('#');
    String newText;
    if (hashIndex != -1) {
      newText = '${currentText.substring(0, hashIndex)}#$title ';
    } else {
      newText = '$currentText #$title ';
    }

    setState(() {
      _tagInputController.text = newText;
      _tagInputController.selection = TextSelection.collapsed(offset: _tagInputController.text.length);
      _tagQuery = '';
    });
  }

  Future<int?> _resolveFirstTagId() async {
    final text = _tagInputController.text.trim();
    if (text.isEmpty) return null;

    final tagMatches = RegExp(r'#([^\s#]+)').allMatches(text);
    final tagNames = tagMatches.map((m) => m.group(1)!.trim()).where((name) => name.isNotEmpty).toList();

    if (tagNames.isEmpty) return null;

    int? firstTagId;

    for (var i = 0; i < tagNames.length; i++) {
      final tagName = tagNames[i];
      int? resolvedId;

      for (final t in _tags) {
        if ((t['title'] as String).toLowerCase() == tagName.toLowerCase()) {
          resolvedId = t['id'] as int;
          break;
        }
      }

      if (resolvedId == null) {
        resolvedId = await TagDao().insert(tagName);
        _tags = await TagDao().getAll();
      }

      if (i == 0) {
        firstTagId = resolvedId;
      }
    }

    return firstTagId;
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
          values[field.id] = [
            for (var i = 0; i < controllers.length; i++)
              if (field.id != QuickQuestionTemplates.choicesId ||
                  controllers[i].text.trim().isNotEmpty)
                OptionValue(text: controllers[i].text.trim(), correct: corrects[i]).toMap(),
          ];
          break;
      }
    }
    values['ux_comment'] = _commentController.text.trim();
    return values;
  }

  Future<void> _save({bool addAnother = false}) async {
    final template = _selectedTemplate;
    if (template == null) {
      _showError(context.tr('qe.pickTemplate'));
      return;
    }
    final templateId = template.id;
    if (templateId == null) {
      _showError(context.tr('qe.pickTemplate'));
      return;
    }
    if (_selectedPackageId == null) {
      _showError(context.tr('qe.pickPackage'));
      return;
    }

    final statementText = _textControllers[FieldDefinition.statementId]?.text.trim() ?? '';
    if (statementText.isEmpty) {
      _showError(context.tr('qe.fillStatement'));
      return;
    }
    if (SimpleQuestionTemplate.matches(template) &&
        (_textControllers[SimpleQuestionTemplate.answerId]?.text.trim().isEmpty ?? true)) {
      _showError(context.tr('qe.fillAnswer'));
      return;
    }
    final quickKind = QuickQuestionTemplates.kindOf(template);
    if (quickKind != null) {
      final fieldId = quickKind == 'multiple'
          ? QuickQuestionTemplates.choicesId : QuickQuestionTemplates.truthId;
      final texts = _optionControllers[fieldId] ?? [];
      final marks = _optionCorrect[fieldId] ?? [];
      final nonEmpty = texts.where((c) => c.text.trim().isNotEmpty).length;
      final selected = <int>[
        for (var i = 0; i < marks.length; i++) if (marks[i]) i,
      ];
      if (nonEmpty < 2 || selected.length != 1 ||
          texts[selected.first].text.trim().isEmpty) {
        _showError(context.tr('ux.optionValidation'));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final values = _collectValues(template);
      final tagId = await _resolveFirstTagId();
      final dto = QuestionDto(
        packageId: _selectedPackageId!,
        tagId: tagId,
        templateId: templateId,
        questions: jsonEncode(values),
      );
      final dao = QuestionDao();
      if (_isEditing) {
        await dao.updateQuestion(widget.question!.id!, dto);
        if (!mounted) return;
        _showError(context.tr('qe.saved'));
        Navigator.pop(context, true);
      } else {
        await dao.insert(dto);
        _createdAny = true;
        if (!mounted) return;
        if (addAnother) {
          setState(_resetForm);
          _initialSnapshot = _formSnapshot();
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
          _showError(context.tr('qe.savedNext'));
        } else {
          _showError(context.tr('qe.saved'));
          Navigator.pop(context, true);
        }
      }
    } catch (error) {
      if (!mounted) return;
      _showError(context.tr('qe.saveFailed', {'error': error}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('qb.deleteQuestion')),
        content: Text(context.tr('qb.deleteQuestionBody',
            {'name': widget.question!.statement})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await QuestionDao().delete(widget.question!.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _showError(context.tr('qe.deleteFailed', {'error': error}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _leave() async {
    if (_saving || _leaving) return;
    _leaving = true;
    try {
      if (_initialSnapshot.isNotEmpty && _formSnapshot() != _initialSnapshot) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.tr('ux.discardTitle')),
            content: Text(context.tr('ux.discardBody')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('common.cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.tr('ux.discard')),
              ),
            ],
          ),
        );
        if (discard != true) return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.pop(context, _createdAny);
    } finally {
      _leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _tagInputController.tagStyle = TextStyle(
      color: context.colors.accent,
      fontWeight: FontWeight.bold,
    );

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
      backgroundColor: context.colors.bgMain,
      appBar: AppBar(
        backgroundColor: context.colors.bgMain,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textMain),
          onPressed: () => _leave(),
        ),
        title: Text(
          context.tr(_isEditing ? 'qe.edit' : 'qe.new'),
          style: TextStyle(color: context.colors.textMain, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: _templates.isEmpty ? _buildNoTemplates() : _buildForm(),
      bottomNavigationBar: _templates.isEmpty ? null : _buildSaveFooter(),
    );
  }

  Widget _buildSaveFooter() {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return SafeArea(
      top: false,
      child: Container(
        color: context.colors.bgMain,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              TextButton(
                onPressed: _saving ? null : _leave,
                child: Text(context.tr('common.cancel')),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: const Icon(Icons.check),
                label: Text(context.tr(_saving ? 'common.saving' : 'qe.save')),
              ),
            ]),
            if (!_isEditing && !keyboardOpen)
              TextButton.icon(
                onPressed: _saving ? null : () => _save(addAnother: true),
                icon: const Icon(Icons.add),
                label: Text(context.tr('qe.saveAndAnother')),
              ),
          ],
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
              context.tr('qe.noTemplates'),
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
              child: Text(context.tr('qe.createTemplate')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final template = _selectedTemplate;
    if (template == null) return _buildNoTemplates();
    final basic = SimpleQuestionTemplate.matches(template);
    final statement = template.fields.firstWhere((f) => f.isStatement);
    final additional = template.fields.where((f) => !f.isStatement &&
        !(basic && f.id == SimpleQuestionTemplate.answerId)).toList();
    final selectedPackage = _packages.where((p) => p['id'] == _selectedPackageId);
    final packageName = selectedPackage.isNotEmpty
        ? selectedPackage.first['title'] as String : context.tr('qe.pickPackage');

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (_selectedPackageId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(context.tr('qe.inPackage', {'name': packageName}),
              style: TextStyle(color: context.colors.textSecond)),
          )
        else
          Text(context.tr('qe.chooseOrCreate'),
            style: TextStyle(color: context.colors.textSecond)),
        if (_selectedPackageId == null)
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: _openNewPackage,
            icon: const Icon(Icons.add),
            label: Text(context.tr('ux.newSubject')),
          )),
        if (basic || QuickQuestionTemplates.kindOf(template) != null) ...[
          _buildQuickTypeSelector(template),
          const SizedBox(height: 16),
        ],
        _buildMarkdownField(statement, labelOverride: context.tr('qe.questionRequired')),
        const SizedBox(height: 16),
        if (basic) ...[
          _buildMarkdownField(
            template.fields.firstWhere((f) => f.id == SimpleQuestionTemplate.answerId),
            labelOverride: context.tr('qe.answerRequired'),
          ),
          const SizedBox(height: 10),
        ] else ...[
          ...additional.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: QuickQuestionTemplates.kindOf(template) != null &&
                    f.type == FieldType.options
                ? _buildQuickOptionsField(f)
                : _buildFieldInput(f),
          )),
        ],
        TextField(
          controller: _commentController,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: context.tr('ux.commentOptional'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          key: ValueKey('advanced_${template.id}'),
          initiallyExpanded: _showAdvanced,
          onExpansionChanged: (expanded) => setState(() => _showAdvanced = expanded),
          tilePadding: EdgeInsets.zero,
          title: Text(context.tr('ux.advancedOptions')),
          children: [
            Row(
              children: [
                Expanded(child: _buildDropdown<int?>(
                  label: context.tr('qb.package'),
                  value: _selectedPackageId,
                  items: _packages.map((p) => DropdownMenuItem(
                    value: p['id'] as int, child: Text(p['title'] as String),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedPackageId = value),
                )),
                IconButton(
                  tooltip: context.tr('pkg.new'),
                  onPressed: _openNewPackage,
                  icon: Icon(Icons.add_circle_outline, color: context.colors.accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildDropdown<TemplateModel?>(
                  label: context.tr('qe.template'),
                  value: _selectedTemplate,
                  items: _templates.map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(_templateLabel(t)),
                  )).toList(),
                  onChanged: (selected) {
                    if (selected == null || selected == _selectedTemplate) return;
                    setState(() {
                      if (_selectedTemplate != null) _saveToBuffer(_selectedTemplate!);
                      _selectedTemplate = selected;
                      _showAdvanced = !SimpleQuestionTemplate.matches(selected);
                      _setupControllersForTemplate(
                        selected, initialValues: _bufferValuesFor(selected));
                    });
                  },
                )),
                IconButton(
                  tooltip: context.tr('qe.createTemplate'),
                  onPressed: _openNewTemplate,
                  icon: Icon(Icons.add_circle_outline, color: context.colors.accent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTagField(),
            const SizedBox(height: 12),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _templateLabel(TemplateModel template) {
    if (SimpleQuestionTemplate.matches(template)) return context.tr('qe.basicTemplate');
    switch (QuickQuestionTemplates.kindOf(template)) {
      case 'multiple': return context.tr('ux.multipleType');
      case 'trueFalse': return context.tr('ux.trueFalseType');
      default: return template.name;
    }
  }

  Widget _buildQuickTypeSelector(TemplateModel template) {
    final selected = SimpleQuestionTemplate.matches(template)
        ? 'open' : QuickQuestionTemplates.kindOf(template)!;
    final choices = <String, TemplateModel>{};
    for (final item in _templates) {
      if (SimpleQuestionTemplate.matches(item)) choices['open'] = item;
      final kind = QuickQuestionTemplates.kindOf(item);
      if (kind != null) choices[kind] = item;
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('quick_type_$selected'),
      initialValue: selected,
      decoration: InputDecoration(
        labelText: context.tr('ux.questionType'),
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: 'open', child: Text(context.tr('ux.openType'))),
        DropdownMenuItem(value: 'multiple', child: Text(context.tr('ux.multipleType'))),
        DropdownMenuItem(value: 'trueFalse', child: Text(context.tr('ux.trueFalseType'))),
      ],
      onChanged: (kind) {
        final chosen = choices[kind];
        if (chosen == null || chosen == _selectedTemplate) return;
        setState(() {
          _saveToBuffer(template);
          _selectedTemplate = chosen;
          _showAdvanced = false;
          _setupControllersForTemplate(chosen,
              initialValues: _bufferValuesFor(chosen));
        });
      },
    );
  }

  Widget _buildQuickOptionsField(FieldDefinition field) {
    final inputs = _optionControllers[field.id] ?? [];
    final correct = _optionCorrect[field.id] ?? [];
    final isTruth = field.id == QuickQuestionTemplates.truthId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('ux.chooseCorrect'),
          style: TextStyle(color: context.colors.textSecond)),
        const SizedBox(height: 8),
        for (var i = 0; i < inputs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              IconButton(
                tooltip: context.tr('ux.markCorrect'),
                onPressed: () => setState(() {
                  for (var j = 0; j < correct.length; j++) {
                    correct[j] = j == i;
                  }
                }),
                icon: Icon(correct[i]
                    ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: correct[i] ? context.colors.accent : context.colors.textSecond),
              ),
              Expanded(child: TextField(
                controller: inputs[i],
                readOnly: isTruth,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: isTruth
                      ? (i == 0 ? context.tr('ux.trueLabel') : context.tr('ux.falseLabel'))
                      : context.tr('qe.option', {'n': i + 1}),
                  border: const OutlineInputBorder(),
                ),
              )),
            ]),
          ),
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
        TextField(
          controller: _tagInputController,
          minLines: 1,
          maxLines: null,
          onChanged: _onTagInputChanged,
          decoration: InputDecoration(
            labelText: context.tr('qe.tagOptional'),
            hintText: context.tr('qe.tagHint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: matches
                .map((t) => ActionChip(
                      label: Text('#${t['title']}'),
                      backgroundColor: context.colors.accent.withValues(alpha: 0.15),
                      side: BorderSide.none,
                      onPressed: () => _selectSuggestedTag(t['title'] as String),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldInput(FieldDefinition field) {
    switch (field.type) {
      case FieldType.text:
        return _buildMarkdownField(field);
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

  Widget _buildMarkdownField(FieldDefinition field, {String? labelOverride}) {
    final controller = _textControllers[field.id]!;
    final label = labelOverride ?? (field.isStatement ? '${field.label}*' : field.label);
    final previewing = _previewing.contains(field.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showAdvanced) ...[
          _buildMarkdownToolbar(field.id, controller, previewing),
          const SizedBox(height: 6),
        ],
        if (previewing)
          _buildMarkdownPreview(controller.text, label, field.isStatement)
        else
          _buildTextField(controller, label, minLines: 3),
      ],
    );
  }

  Widget _buildMarkdownPreview(String text, String label, bool isStatement) {
    final empty = text.trim().isEmpty;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.bgSecond),
        borderRadius: BorderRadius.circular(10),
      ),
      child: empty
          ? Text(context.tr('qe.nothingToPreview', {'label': label}), style: TextStyle(fontSize: 13, color: context.colors.textSecond))
          : MarkdownText(
              text: text,
              style: TextStyle(
                fontSize: isStatement ? 16 : 14,
                color: context.colors.textMain,
              ),
            ),
    );
  }

  Widget _buildMarkdownToolbar(String fieldId, TextEditingController c, bool previewing) {
    Widget btn(IconData icon, String tip, VoidCallback onTap) => IconButton(
          icon: Icon(icon, size: context.icon(20)),
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          color: context.colors.textSecond,
          onPressed: previewing ? null : onTap,
        );

    return ExcludeFocus(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            btn(Icons.format_bold, context.tr('qe.bold'), () => _wrapSelection(c, '**')),
            btn(Icons.format_italic, context.tr('qe.italic'), () => _wrapSelection(c, '*')),
            btn(Icons.code, context.tr('qe.code'), () => _wrapSelection(c, '`')),
            btn(Icons.link, context.tr('qe.link'), () => _wrapSelection(c, '[', '](https://)')),
            btn(Icons.format_list_bulleted, context.tr('qe.list'), () => _prefixLines(c, '- ')),
            btn(Icons.format_list_numbered, context.tr('qe.numberedList'), () => _prefixLines(c, '1. ')),
            btn(Icons.format_quote, context.tr('qe.quote'), () => _prefixLines(c, '> ')),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(previewing ? Icons.edit_outlined : Icons.visibility_outlined, size: context.icon(20)),
              tooltip: context.tr(previewing ? 'qe.backToEdit' : 'qe.preview'),
              visualDensity: VisualDensity.compact,
              color: context.colors.accent,
              onPressed: () => setState(() {
                if (!_previewing.remove(fieldId)) _previewing.add(fieldId);
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _wrapSelection(TextEditingController c, String left, [String? right]) {
    right ??= left;
    final text = c.text;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);

    c.value = TextEditingValue(
      text: text.replaceRange(start, end, '$left$selected$right'),
      selection: TextSelection(
        baseOffset: start + left.length,
        extentOffset: start + left.length + selected.length,
      ),
    );
  }

  void _prefixLines(TextEditingController c, String prefix) {
    final text = c.text;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;

    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final nl = text.indexOf('\n', end);
    final lineEnd = nl == -1 ? text.length : nl;

    final prefixed = text.substring(lineStart, lineEnd).split('\n').map((l) => '$prefix$l').join('\n');
    c.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, prefixed),
      selection: TextSelection(baseOffset: lineStart, extentOffset: lineStart + prefixed.length),
    );
  }

  Widget _buildMediaField(FieldDefinition field, {required bool isImage}) {
    final path = _mediaPaths[field.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(field.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textMain)),
        const SizedBox(height: 8),
        if (path != null) ...[
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: MediaImage(path: path, height: 140, fit: BoxFit.cover, width: double.infinity),
            )
          else
            Row(children: [
              Icon(Icons.audiotrack, color: context.colors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(p.basename(path), overflow: TextOverflow.ellipsis)),
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
                label: Text(context.tr('qe.gallery')),
              ),
              TextButton.icon(
                onPressed: () => _pickImage(field.id, fromCamera: true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(context.tr('qe.camera')),
              ),
            ] else
              TextButton.icon(
                onPressed: () => _pickAudio(field.id),
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(context.tr('qe.pickAudio')),
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
          context.tr(
            field.type == FieldType.options ? 'qe.optionsHint' : 'qe.trueFalseHint',
            {'label': field.label},
          ),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textMain),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          controllers.length,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: corrects[i],
                  onChanged: (v) => setState(() => _optionCorrect[field.id]![i] = v ?? false),
                  activeColor: const Color(0xFF2E7D32),
                ),
                Expanded(
                  child: TextField(
                    controller: controllers[i],
                    minLines: 1,
                    maxLines: null, 
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: context.tr('qe.option', {'n': i + 1}),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: null, 
      keyboardType: keyboardType ?? TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
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
      key: ValueKey('$label:$value'),
      initialValue: value,
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