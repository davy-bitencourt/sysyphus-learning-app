import 'package:flutter/material.dart';
import '../data/DAO/package_dao.dart';
import '../data/DAO/session_dao.dart';
import '../data/DAO/question_state_dao.dart';
import '../l10n/strings.dart';
import '../styles/app_theme.dart';
import 'questions_edit_screen.dart';

class PackageEditScreen extends StatefulWidget {
  final int? packageId;
  final String? initialTitle;
  final int? initialSessionId;
  final bool allowAddQuestions;

  const PackageEditScreen({
    super.key,
    this.packageId,
    this.initialTitle,
    this.initialSessionId,
    this.allowAddQuestions = true,
  });

  @override
  State<PackageEditScreen> createState() => _PackageEditScreenState();
}

class _PackageEditScreenState extends State<PackageEditScreen> {
  final _titleController = TextEditingController();
  List<Map<String, dynamic>> _sessions = [];
  int? _selectedSessionId;
  bool _loading = true;
  bool _saving = false;
  bool _createdAny = false;
  bool _leaving = false;
  String _originalTitle = '';
  int? _originalSessionId;

  bool get _isEditing => widget.packageId != null;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    _selectedSessionId = widget.initialSessionId;
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    _sessions = await SessionDao().getAll();

    if (_isEditing && _selectedSessionId == null) {
      final rows = await PackageDao().getAll();
      for (final row in rows) {
        if (row['id'] == widget.packageId) {
          _selectedSessionId = row['session_id'] as int?;
          break;
        }
      }
    }

    if (_selectedSessionId != null &&
        !_sessions.any((s) => s['id'] == _selectedSessionId)) {
      _selectedSessionId = null;
    }

    _originalTitle = _titleController.text;
    _originalSessionId = _selectedSessionId;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save({bool addQuestions = false}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pkg.nameRequired'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final dao = PackageDao();
      if (_isEditing) {
        await dao.update(widget.packageId!, _selectedSessionId, title);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('pkg.saved', {'title': title}))),
        );
        Navigator.pop(context, true);
      } else {
        final newId = await dao.insert(_selectedSessionId, title);
        _createdAny = true;
        if (!mounted) return;
        if (addQuestions) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => QuestionsEditScreen(packageId: newId)),
          );
          if (!mounted) return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('pkg.saved', {'title': title}))),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pkg.saveFailed', {'error': error}))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;

    final title = _titleController.text.trim().isEmpty
        ? (widget.initialTitle ?? '')
        : _titleController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('pkg.deleteTitle')),
        content: Text(context.tr('pkg.deleteBody', {'title': title})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('pkg.deleteAll'), style: const TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await QuestionDao().deletePackageCascade(widget.packageId!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao excluir pacote ${widget.packageId}: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pkg.deleteFailed', {'error': e}))),
      );
    }
  }

  Future<void> _leave() async {
    if (_saving || _leaving) return;
    _leaving = true;
    try {
      if (_titleController.text != _originalTitle ||
          _selectedSessionId != _originalSessionId) {
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
        title: Text(context.tr(_isEditing ? 'pkg.edit' : 'pkg.new'),
          style: TextStyle(color: context.colors.textMain,
            fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _titleController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) { if (!_saving) _save(); },
                  decoration: InputDecoration(
                    labelText: context.tr('pkg.name'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                if (_sessions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: _selectedSessionId != null,
                    title: Text(context.tr('ux.advancedOptions')),
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: _selectedSessionId,
                        items: [
                          DropdownMenuItem(value: null, child: Text(context.tr('pkg.noSession'))),
                          ..._sessions.map((session) => DropdownMenuItem(
                            value: session['id'] as int,
                            child: Text((session['title'] as String?) ??
                                context.tr('pkg.sessionFallback', {'id': session['id'] as Object})),
                          )),
                        ],
                        onChanged: (value) => setState(() => _selectedSessionId = value),
                        decoration: InputDecoration(
                          labelText: context.tr('pkg.sessionOptional'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: context.colors.bgMain,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isEditing && widget.allowAddQuestions) ...[
                ElevatedButton.icon(
                  onPressed: (_saving || _loading) ? null : () => _save(addQuestions: true),
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('pkg.createAndAdd')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              ElevatedButton(
                onPressed: (_saving || _loading) ? null : () => _save(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEditing || !widget.allowAddQuestions
                      ? context.colors.accent : context.colors.bgSecond,
                  foregroundColor: _isEditing || !widget.allowAddQuestions
                      ? Colors.white : context.colors.textMain,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(context.tr(_saving ? 'common.saving' : 'pkg.save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
