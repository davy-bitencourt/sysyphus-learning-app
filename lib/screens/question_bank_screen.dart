import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../data/DAO/package_dao.dart';
import '../data/DAO/template_dao.dart';
import '../data/DAO/tag_dao.dart';
import '../data/DAO/question_state_dao.dart';
import '../data/models/field_model.dart';
import '../data/models/question_model.dart';
import 'home.dart';
import 'package_edit_screen.dart';
import 'questions_edit_screen.dart';
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

    if (!mounted) return;
    setState(() {
      _packages = List.from(packageRows);
      _templates = templateRows
          .map((row) => TemplateModel.fromJson(row['id'] as int, row['template'] as String))
          .toList();
      _tags = List.from(tagRows);
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
      length: 4,
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

    return Padding(
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

// --- ABA 2: PACOTES (REORDENÁVEL COM DRAG HANDLE NO INÍCIO) ---
  Widget _buildPackagesTab() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      buildDefaultDragHandles: false, // Desativa o drag handle padrão no final
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

  // --- ABA 3: TEMPLATES (REORDENÁVEL COM DRAG HANDLE NO INÍCIO) ---
  Widget _buildTemplatesTab() {
    return Column(
      children: [
        Expanded(
          child: _templates.isEmpty
              ? Center(child: Text('Nenhum template cadastrado.', style: TextStyle(color: Colors.grey[500])))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  buildDefaultDragHandles: false, // Desativa o drag handle padrão no final
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
    return ListView.separated(
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
    );
  }
}