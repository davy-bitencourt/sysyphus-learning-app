import 'package:flutter/material.dart';
import '../styles/app_theme.dart';

import '../data/DAO/package_dao.dart';
import 'home.dart';
import '../data/DAO/template_dao.dart';
import '../data/models/field_model.dart';
import '../data/models/question_model.dart';
import '../data/DAO/question_state_dao.dart';
import 'package_edit_screen.dart';
import 'questions_edit_screen.dart';
import 'templaate_edit_screen.dart';

/// Tela de gerenciamento do banco de questões e templates da aplicação.
///
/// Acessada pelo item "Questions finder" do menu lateral. Reúne, em duas
/// abas: a busca de questões por pacote (via dropdown) e a lista de
/// templates cadastrados, com opção de editar/excluir.
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  List<Map<String, dynamic>> _packages = [];
  List<TemplateModel> _templates = [];
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

    if (!mounted) return;
    setState(() {
      _packages = packageRows;
      _templates = templateRows
          .map((row) => TemplateModel.fromJson(row['id'] as int, row['template'] as String))
          .toList();
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
    // Tela de gerenciamento: traz TODAS as questões do pacote, em ordem
    // estável (o getByPackage é de estudo: aleatório e limitado a 60).
    final rows = await QuestionDao().getAllByPackage(packageId);
    final loaded = rows.map((row) => Question.fromDb(row)).toList();

    if (!mounted) return;
    setState(() {
      _packageQuestions = loaded;
      _loadingQuestions = false;
    });
  }

  Future<void> _openNewTemplate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
    );
    if (result == true) _load();
  }

  // Abre o template selecionado para edição — TemplateEditScreen recebe o
  // TemplateModel completo (não um id) no parâmetro `template`.
  Future<void> _editTemplate(TemplateModel template) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TemplateEditScreen(template: template)),
    );
    if (result == true) _load();
  }

  Future<void> _deleteTemplate(TemplateModel template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir template'),
        content: Text(
          'Tem certeza que deseja excluir "${template.name}"? '
          'Questões que usam esse template podem parar de funcionar corretamente.',
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
    if (confirmed != true || template.id == null) return;

    await TemplateDao().delete(template.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.colors.bg,
        appBar: AppBar(
          backgroundColor: context.colors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Banco de questões',
            style: TextStyle(color: context.colors.text, fontWeight: FontWeight.bold, fontSize: 20)),
          bottom: TabBar(
            labelColor: context.colors.accent,
            unselectedLabelColor: Color(0xFF9E9E9E),
            indicatorColor: context.colors.accent,
            tabs: [
              Tab(text: 'Questões'),
              Tab(text: 'Templates'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildQuestionsTab(),
                  _buildTemplatesTab(),
                ],
              ),
      ),
    );
  }

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
                    Home.packagesChanged.value++; // avisa a Home
                    _load();
                  }
                },
                icon: Icon(Icons.settings, color: Colors.grey[400]),
              ),
              IconButton(
                onPressed: () => _deleteSelectedPackage(selectedPackage),
                icon: const Icon(Icons.delete_outline, color: Color(0xFFC62828)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildQuestionsList()),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedPackage(Map<String, dynamic> package) async {
    final id = package['id'] as int;
    final title = package['title'] as String;
    final count = _packageQuestions.length;
    final questionsText = count == 1 ? 'a 1 questão' : 'as $count questões';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir pacote'),
        content: Text(
          'Tem certeza que deseja excluir o pacote "$title"?\n\n'
          'Isso apagará também $questionsText dele. O histórico de revisões '
          '(heatmap) é mantido. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir tudo', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await QuestionDao().deletePackageCascade(id);
    } catch (e) {
      debugPrint('Erro ao excluir pacote $id: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir o pacote: $e')),
      );
      return;
    }

    if (!mounted) return;
    // O pacote selecionado deixou de existir: zera a seleção pro _load()
    // escolher o primeiro que sobrou.
    setState(() {
      _selectedPackageId = null;
      _packageQuestions = [];
    });
    Home.packagesChanged.value++; // avisa a Home
    await _load();
  }

  // Título = enunciado (campo obrigatório de todo template).
  String _titleOf(Question q) => q.statement.isEmpty ? '(sem enunciado)' : q.statement;

  Future<void> _editQuestion(Question question) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionsEditScreen(question: question, packageId: _selectedPackageId),
      ),
    );
    if (result == true) _loadQuestionsForSelectedPackage();
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir questão'),
        content: Text('Tem certeza que deseja excluir "${_titleOf(question)}"?'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir: $e')),
      );
    }
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
                  _titleOf(question),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: context.colors.text),
                ),
              ),
              IconButton(
                onPressed: () => _editQuestion(question),
                icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey[500]),
              ),
              IconButton(
                onPressed: () => _deleteQuestion(question),
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFC62828)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplatesTab() {
    return Column(
      children: [
        Expanded(
          child: _templates.isEmpty
              ? Center(
                  child: Text('Nenhum template cadastrado ainda.', style: TextStyle(color: Colors.grey[500])),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _templates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final template = _templates[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.dashboard_customize_outlined,
                            color: context.colors.accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(template.name,
                              style: TextStyle(fontSize: 14, color: context.colors.text)),
                          ),
                          Text('${template.fields.length} campos',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          IconButton(
                            onPressed: () => _editTemplate(template),
                            icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey[500]),
                          ),
                          IconButton(
                            onPressed: () => _deleteTemplate(template),
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFC62828)),
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
                onPressed: _openNewTemplate,
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
}
