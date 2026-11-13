import 'dart:convert';
import 'dart:io';
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
import '../data/services/media_storage_service.dart';
import 'package_edit_screen.dart';
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

  /// Campos de texto que estão mostrando a prévia do Markdown (ids).
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

  bool _loading = true;
  bool _saving = false;
  bool _createdAny = false; 

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
      _selectedPackageId = q.packageId ?? widget.packageId;

      if (q.tagId != null) {
        final match = _tags.firstWhere(
          (t) => t['id'] == q.tagId,
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
        _setupControllersForTemplate(
          _selectedTemplate!,
          initialValues: {...q.values, ..._bufferValuesFor(_selectedTemplate!)},
        );
      }
    } else if (_templates.isNotEmpty) {
      _selectedTemplate = _templates.first;
      _setupControllersForTemplate(
        _selectedTemplate!,
        initialValues: _bufferValuesFor(_selectedTemplate!),
      );
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
    final previousIds = _packages.map((p) => p['id']).toSet();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PackageEditScreen()),
    );
    if (result != true || !mounted) return;

    final rows = await PackageDao().getAll();
    if (!mounted) return;
    final created = rows.where((p) => !previousIds.contains(p['id'])).toList();
    setState(() {
      _packages = rows;
      if (created.isNotEmpty) _selectedPackageId = created.last['id'] as int;
    });
  }

  Future<void> _openNewTemplate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
    );
    if (result == true) {
      if (_selectedTemplate != null) _saveToBuffer(_selectedTemplate!);
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
    for (final list in _optionCorrect.values) {
      for (var i = 0; i < list.length; i++) {
        list[i] = false;
      }
    }
    _tagInputController.clear();
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
          values[field.id] = List.generate(
            controllers.length,
            (i) => OptionValue(text: controllers[i].text.trim(), correct: corrects[i]).toMap(),
          );
          break;
      }
    }
    return values;
  }

  Future<void> _save() async {
    if (_selectedTemplate == null || _selectedTemplate!.id == null) {
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

    setState(() => _saving = true);

    final values = _collectValues(_selectedTemplate!);
    final tagId = await _resolveFirstTagId();

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
        if (mounted) Navigator.pop(context, true);
      } else {
        await dao.insert(dto);
        _createdAny = true;
        if (!mounted) return;
        setState(_resetForm);
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
        _showError(context.tr('qe.saved'));
      }
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

  void _leave() {
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.pop(context, _createdAny);
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
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.text),
          onPressed: () => _leave(),
        ),
        title: Text(
          context.tr(_isEditing ? 'qe.edit' : 'qe.new'),
          style: TextStyle(color: context.colors.text, fontWeight: FontWeight.bold, fontSize: 20),
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
            child: Text(context.tr(_saving ? 'common.saving' : 'qe.save'), style: const TextStyle(fontSize: 15)),
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
    final questionFields = template?.questionFields ?? const [];
    final answerFields = template?.answerFields ?? const [];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown<int?>(
                label: context.tr('qb.package'),
                value: _selectedPackageId,
                items: _packages
                    .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['title'] as String)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPackageId = v),
              ),
            ),
            IconButton(
              onPressed: _openNewPackage,
              icon: Icon(Icons.add_circle_outline, color: context.colors.accent),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown<TemplateModel?>(
                label: context.tr('qe.template'),
                value: _selectedTemplate,
                items: _templates.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (t) {
                  if (t == null || t == _selectedTemplate) return;
                  setState(() {
                    if (_selectedTemplate != null) _saveToBuffer(_selectedTemplate!);
                    _selectedTemplate = t;
                    _setupControllersForTemplate(t, initialValues: _bufferValuesFor(t));
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
        const SizedBox(height: 16),
        _buildTagField(),
        const SizedBox(height: 20),
        if (template != null) ...[
          ...questionFields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildFieldInput(f),
              )),
          if (answerFields.isNotEmpty) ...[
            Divider(
              color: context.colors.border,
              thickness: 1.5,
              height: 1.5,
            ),
            const SizedBox(height: 20),
            ...answerFields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildFieldInput(f),
                )),
          ],
        ],
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

  // ---------------------------------------------------------------- markdown

  Widget _buildMarkdownField(FieldDefinition field) {
    final controller = _textControllers[field.id]!;
    final label = field.isStatement ? '${field.label}*' : field.label;
    final previewing = _previewing.contains(field.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMarkdownToolbar(field.id, controller, previewing),
        const SizedBox(height: 6),
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
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: empty
          ? Text(context.tr('qe.nothingToPreview', {'label': label}), style: TextStyle(fontSize: 13, color: context.colors.mutedText))
          : MarkdownText(
              text: text,
              style: TextStyle(
                fontSize: isStatement ? 16 : 14,
                color: context.colors.text,
              ),
            ),
    );
  }

  Widget _buildMarkdownToolbar(String fieldId, TextEditingController c, bool previewing) {
    Widget btn(IconData icon, String tip, VoidCallback onTap) => IconButton(
          icon: Icon(icon, size: context.icon(20)),
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          color: context.colors.mutedText,
          onPressed: previewing ? null : onTap,
        );

    // ExcludeFocus: tocar num botão não tira o foco (nem fecha o teclado) do campo.
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

  /// Envolve a seleção com [left]/[right] (ex.: **texto**). Sem seleção,
  /// insere o par e deixa o cursor no meio.
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

  /// Coloca [prefix] no começo de cada linha tocada pela seleção.
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
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.text),
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