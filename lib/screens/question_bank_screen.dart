import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../data/DAO/package_dao.dart';
import '../data/DAO/template_dao.dart';
import '../data/DAO/tag_dao.dart';
import '../data/DAO/session_dao.dart';
import '../data/DAO/question_state_dao.dart';
import '../data/models/field_model.dart';
import '../data/models/question_model.dart';
import 'home.dart';
import 'package_edit_screen.dart';
import 'questions_edit_screen.dart';
import 'session_edit_screen.dart';
import 'templaate_edit_screen.dart';

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  List<Map<String, dynamic>> _packages = [];
  List<TemplateModel> _templates = [];
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  int? _selectedPackageId;
  List<Question> _packageQuestions = [];
  bool _loadingQuestions = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final packageRows = await PackageDao().getAll();
    final templateRows = await TemplateDao().getAll();
    final tagRows = await TagDao().getAll();
    final sessionRows = await SessionDao().getAll();

    if (!mounted) return;
    setState(() {
      _packages = List.from(packageRows);
      _templates = templateRows
          .map((row) => TemplateModel.fromJson(row['id'] as int, row['template'] as String))
          .toList();
      _tags = List.from(tagRows);
      _sessions = List.from(sessionRows);
      _loading = false;
    });

    if (_packages.isNotEmpty) {
      _selectedPackageId ??= _packages.first['id'] as int;
      await _loadQuestionsForSelectedPackage();
    }
  }

  Future<void> _loadQuestionsForSelectedPackage() async {
    final packageId = _selectedPackageId;
    if (packageId == null) return;

    setState(() => _loadingQuestions = true);
    final rows = await QuestionDao().getAllByPackage(packageId);
    final loaded = rows.map((row) => Question.fromDb(row)).toList();

    if (!mounted) return;
    setState(() {
      _packageQuestions = loaded;
      _loadingQuestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: context.colors.bg,
        appBar: AppBar(
          backgroundColor: context.colors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Banco de questões',
            style: TextStyle(color: context.colors.text, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: context.colors.accent,
            unselectedLabelColor: const Color(0xFF9E9E9E),
            indicatorColor: context.colors.accent,
            tabs: const [
              Tab(text: 'Questões'),
              Tab(text: 'Pacotes'),
              Tab(text: 'Templates'),
              Tab(text: 'Tags'),
              Tab(text: 'Sessões'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildQuestionsTab(),
                  _buildPackagesTab(),
                  _buildTemplatesTab(),
                  _buildTagsTab(),
                  _buildSessionsTab(),
                ],
              ),
      ),
    );
  }

  // --- ABA 1: QUESTÕES ---
  Widget _buildQuestionsTab() {
    if (_packages.isEmpty) {
      return Center(
        child: Text('Nenhum pacote cadastrado ainda.', style: TextStyle(color: Colors.grey[500])),
      );
    }

    final selectedPackage = _packages.firstWhere(
      (p) => p['id'] == _selectedPackageId,
      orElse: () => _packages.first,
    );

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedPackageId,
                        items: _packages
                            .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['title'] as String)))
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          setState(() => _selectedPackageId = id);
                          _loadQuestionsForSelectedPackage();
                        },
                        decoration: InputDecoration(
                          labelText: 'Pacote',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PackageEditScreen(
                              packageId: selectedPackage['id'] as int,
                              initialTitle: selectedPackage['title'] as String,
                            ),
                          ),
                        );
                        if (result == true) {
                          Home.packagesChanged.value++;
                          _load();
                        }
                      },
                      icon: Icon(Icons.settings, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildQuestionsList()),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestionsEditScreen(packageId: _selectedPackageId),
                    ),
                  );
                  if (result == true) _loadQuestionsForSelectedPackage();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nova questão'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsList() {
    if (_loadingQuestions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_packageQuestions.isEmpty) {
      return Center(
        child: Text('Nenhuma questão neste pacote ainda.', style: TextStyle(color: Colors.grey[500])),
      );
    }
    return ListView.separated(
      itemCount: _packageQuestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final question = _packageQuestions[i];
        final title = question.statement.isEmpty ? '(sem enunciado)' : question.statement;
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.only(left: 14, right: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: context.colors.text),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestionsEditScreen(question: question, packageId: _selectedPackageId),
                    ),
                  );
                  if (result == true) _loadQuestionsForSelectedPackage();
                },
                icon: Icon(Icons.edit_outlined, size: context.icon(18), color: Colors.grey[500]),
              ),
              IconButton(
                onPressed: () => _deleteQuestion(question),
                icon: Icon(Icons.delete_outline, size: context.icon(18), color: const Color(0xFFC62828)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir questão'),
        content: Text('Tem certeza que deseja excluir "${question.statement.isEmpty ? '(sem enunciado)' : question.statement}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true || question.id == null) return;

    try {
      await QuestionDao().delete(question.id!);
      _loadQuestionsForSelectedPackage();
    } catch (e) {
      debugPrint('Erro ao excluir questão ${question.id}: $e');
    }
  }

  // --- ABA 2: PACOTES (REORDENÁVEL) ---
  Widget _buildPackagesTab() {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            buildDefaultDragHandles: false,
            itemCount: _packages.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _packages.removeAt(oldIndex);
                _packages.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final pkg = _packages[index];
              return Container(
                key: ValueKey(pkg['id']),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_handle, color: Colors.grey[500]),
                  ),
                  title: Text(pkg['title'] as String, style: TextStyle(color: context.colors.text)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                    onPressed: () => _deletePackage(pkg),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PackageEditScreen()),
                  );
                  if (result == true) {
                    Home.packagesChanged.value++;
                    _load();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Novo pacote'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deletePackage(Map<String, dynamic> pkg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Pacote'),
        content: Text('Deseja excluir o pacote "${pkg['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await QuestionDao().deletePackageCascade(pkg['id'] as int);
      Home.packagesChanged.value++;
      _load();
    }
  }

  // --- ABA 3: TEMPLATES (REORDENÁVEL) ---
  Widget _buildTemplatesTab() {
    return Column(
      children: [
        Expanded(
          child: _templates.isEmpty
              ? Center(child: Text('Nenhum template cadastrado.', style: TextStyle(color: Colors.grey[500])))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  buildDefaultDragHandles: false,
                  itemCount: _templates.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = _templates.removeAt(oldIndex);
                      _templates.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, i) {
                    final template = _templates[i];
                    return Container(
                      key: ValueKey(template.id ?? i),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Icon(Icons.drag_handle, color: Colors.grey[500]),
                            ),
                          ),
                          Expanded(
                            child: Text(template.name, style: TextStyle(fontSize: 14, color: context.colors.text)),
                          ),
                          Text('${template.fields.length} campos', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          IconButton(
                            onPressed: () async {
                              final res = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TemplateEditScreen(template: template)),
                              );
                              if (res == true) _load();
                            },
                            icon: Icon(Icons.edit_outlined, size: context.icon(18), color: Colors.grey[500]),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (template.id != null) {
                                await TemplateDao().delete(template.id!);
                                _load();
                              }
                            },
                            icon: Icon(Icons.delete_outline, size: context.icon(18), color: const Color(0xFFC62828)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
                  );
                  if (result == true) _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Novo template'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- ABA 4: TAGS ---
  Widget _buildTagsTab() {
    final titleController = TextEditingController();

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _tags.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final tag = _tags[i];
              return Container(
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text('#${tag['title']}', style: TextStyle(color: context.colors.text, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
                    onPressed: () async {
                      await TagDao().delete(tag['id'] as int);
                      _load();
                    },
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final title = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Nova Tag'),
                      content: TextField(
                        controller: titleController,
                        decoration: const InputDecoration(hintText: 'Nome da tag (sem #)'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, titleController.text.trim()),
                          child: const Text('Adicionar'),
                        ),
                      ],
                    ),
                  );

                  if (title != null && title.isNotEmpty) {
                    final cleanTitle = title.replaceAll('#', '').trim();
                    if (cleanTitle.isNotEmpty) {
                      await TagDao().insert(cleanTitle);
                      _load();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nova tag'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- ABA 5: SESSÕES ---
  Widget _buildSessionsTab() {
    return Column(
      children: [
        Expanded(
          child: _sessions.isEmpty
              ? Center(child: Text('Nenhuma sessão cadastrada ainda.', style: TextStyle(color: Colors.grey[500])))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final session = _sessions[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, color: context.colors.accent, size: context.icon(20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (session['title'] as String?) ?? 'Sessão ${session['id']}',
                                  style: TextStyle(fontSize: 14, color: context.colors.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _sessionSummary(session),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _editSession(session),
                            icon: Icon(Icons.edit_outlined, size: context.icon(18), color: Colors.grey[500]),
                          ),
                          IconButton(
                            onPressed: () => _deleteSession(session),
                            icon: Icon(Icons.delete_outline, size: context.icon(18), color: const Color(0xFFC62828)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SessionEditScreen()),
                  );
                  if (result == true) _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Nova sessão'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Resumo em uma linha: tempo • total de questões • filtro por tag.
  String _sessionSummary(Map<String, dynamic> session) {
    final minutes = int.tryParse((session['time_limit'] as String?) ?? '');
    final total = (session['total_q'] as num?)?.toInt();
    final parts = <String>[
      minutes == null ? 'Sem limite de tempo' : '$minutes min',
      if (total != null) '$total questões',
    ];

    final filters = SessionDao.parseTagFilters(session['tag_filters'] as String?);
    if (filters.isNotEmpty) {
      final names = {for (final t in _tags) t['id'] as int: t['title'] as String};
      parts.add(filters.map((f) => '#${names[f['tag_id']] ?? '?'} ${f['quantity']}').join(' · '));
    }
    return parts.join(' • ');
  }

  Future<void> _editSession(Map<String, dynamic> session) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionEditScreen(session: session)),
    );
    if (result == true) _load();
  }

  Future<void> _deleteSession(Map<String, dynamic> session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir sessão'),
        content: Text(
          'Tem certeza que deseja excluir a sessão "${session['title'] ?? ''}"? '
          'Os pacotes ligados a ela ficarão sem sessão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SessionDao().delete(session['id'] as int);
      _load();
    } catch (e) {
      debugPrint('Erro ao excluir sessão ${session['id']}: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir a sessão: $e')),
      );
    }
  }
}
