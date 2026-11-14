import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../styles/app_theme.dart';
import '../widgets/new_tag_dialog.dart';
import 'pack_transfer.dart';
import '../data/DAO/package_dao.dart';
import '../data/DAO/template_dao.dart';
import '../data/DAO/tag_dao.dart';
import '../data/DAO/session_dao.dart';
import '../data/DAO/question_state_dao.dart';
import '../data/models/field_model.dart';
import '../data/models/question_model.dart';
import '../data/services/order_service.dart';
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

  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  String _norm(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    var out = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  bool _matches(String text) => _query.isEmpty || _norm(text).contains(_norm(_query));

  Widget _noResults() => Center(
        child: Text(context.tr('qb.noResults'), style: TextStyle(color: Colors.grey[500])),
      );

  Widget _itemMenu({
    VoidCallback? onEdit,
    VoidCallback? onExport,
    required VoidCallback onDelete,
  }) {
    const danger = Color(0xFFC62828);

    PopupMenuItem<String> item(String value, IconData icon, String label, {Color? color}) {
      final c = color ?? context.colors.textMain;
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: context.icon(20), color: c),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: c)),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: context.tr('common.options'),
      color: context.colors.bgSecond,
      icon: Icon(Icons.more_vert, size: context.icon(20), color: Colors.grey[500]),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
          case 'export':
            onExport?.call();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) => [
        if (onEdit != null) item('edit', Icons.edit_outlined, context.tr('common.edit')),
        if (onExport != null) item('export', Icons.file_upload_outlined, context.tr('common.export')),
        item('delete', Icons.delete_outline, context.tr('common.delete'), color: danger),
      ],
    );
  }

  Future<void> _editQuestion(Question question) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionsEditScreen(question: question, packageId: _selectedPackageId),
      ),
    );
    if (result == true) _loadQuestionsForSelectedPackage();
  }

  Future<void> _editPackage(Map<String, dynamic> pkg) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PackageEditScreen(
          packageId: pkg['id'] as int,
          initialTitle: pkg['title'] as String,
        ),
      ),
    );
    if (result == true) {
      Home.packagesChanged.value++;
      _load();
    }
  }

  Future<void> _exportPackage(Map<String, dynamic> pkg) async {
    await startPackExport(context, packageIds: {pkg['id'] as int});
  }

  Future<void> _editTemplate(TemplateModel template) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TemplateEditScreen(template: template)),
    );
    if (res == true) _load();
  }

  Future<void> _deleteTemplate(TemplateModel template) async {
    if (template.id == null) return;
    await TemplateDao().delete(template.id!);
    _load();
  }


  static const double _handleW = 40;
  static const double _idW = 44;

  Future<void> _persistPackageOrder() async {
    await OrderService.save(
      OrderService.packagesKey,
      _packages.map((p) => p['id'] as int).toList(),
    );
    Home.packagesChanged.value++; // a Home recarrega na nova ordem
  }

  Future<void> _persistTemplateOrder() => OrderService.save(
        OrderService.templatesKey,
        _templates.map((t) => t.id).whereType<int>().toList(),
      );

  // ---- helpers de tabela -------------------------------------------------
  // Cada coluna é (rótulo/texto, flex). flex 0 = largura fixa (coluna de ID).

  Widget _cell(int flex, Widget child) =>
      flex <= 0 ? SizedBox(width: _idW, child: child) : Expanded(flex: flex, child: child);

  Widget _tableHeader(List<(String, int)> cols, {bool handle = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.bgSecond, width: 2)),
      ),
      child: Row(
        children: [
          if (handle) const SizedBox(width: _handleW),
          for (final c in cols)
            _cell(
              c.$2,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  c.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500]),
                ),
              ),
            ),
          const SizedBox(width: 48), // espaço do menu ⋮
        ],
      ),
    );
  }

  Widget _tableRow({
    required Key key,
    required List<(String, int)> cells,
    required Widget menu,
    Widget? handle,
  }) {
    return Container(
      key: key,
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.bgSecond)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            if (handle != null) SizedBox(width: _handleW, child: handle),
            for (final c in cells)
              _cell(
                c.$2,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    c.$1,
                    maxLines: c.$2 <= 0 ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: c.$2 <= 0 ? Colors.grey[500] : context.colors.textMain,
                    ),
                  ),
                ),
              ),
            menu,
          ],
        ),
      ),
    );
  }

  Widget _dragHandle(int index) => ReorderableDragStartListener(
        index: index,
        child: Icon(Icons.drag_handle, color: Colors.grey[500]),
      );

  Widget _tableShell({required Widget header, required Widget list}) => Column(
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: header),
          Expanded(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: list),
          ),
        ],
      );

  Widget _tagsTable(List<Map<String, dynamic>> rows) {
    const cols = [('ID', 0), ('Tag', 6)];
    return _tableShell(
      header: _tableHeader(cols),
      list: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final tag = rows[i];
          return _tableRow(
            key: ValueKey(tag['id']),
            cells: [('${tag['id']}', 0), ('#${tag['title']}', 6)],
            menu: _itemMenu(onDelete: () => _deleteTag(tag)),
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final packageRows = await OrderService.apply(
        OrderService.packagesKey, await PackageDao().getAll(), (p) => p['id'] as int);
    final templateRows = await OrderService.apply(
        OrderService.templatesKey, await TemplateDao().getAll(), (t) => t['id'] as int);
    final tagRows = await TagDao().getAll();
    final sessionRows = await SessionDao().getAll();

    if (!mounted) return;

    final packageIds = packageRows.map((p) => p['id'] as int).toList();
    final selected = packageIds.contains(_selectedPackageId)
        ? _selectedPackageId
        : (packageIds.isEmpty ? null : packageIds.first);

    setState(() {
      _packages = List.from(packageRows);
      _selectedPackageId = selected;
      if (selected == null) _packageQuestions = [];
      _templates = templateRows
          .map((row) => TemplateModel.fromJson(row['id'] as int, row['template'] as String))
          .toList();
      _tags = List.from(tagRows);
      _sessions = List.from(sessionRows);
      _loading = false;
    });

    if (selected != null) {
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
        backgroundColor: context.colors.bgMain,
        appBar: AppBar(
          backgroundColor: context.colors.bgMain,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          title: _searching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: TextStyle(color: context.colors.textMain, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: context.tr('qb.searchHint'),
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  context.tr('qb.title'),
                  style: TextStyle(color: context.colors.textMain, fontWeight: FontWeight.bold, fontSize: 20),
                ),
          actions: [
            IconButton(
              tooltip: context.tr(_searching ? 'qb.closeSearch' : 'qb.search'),
              icon: Icon(_searching ? Icons.close : Icons.search, color: context.colors.textMain),
              onPressed: _toggleSearch,
            ),
            PopupMenuButton<String>(
              tooltip: context.tr('qb.importExport'),
              icon: Icon(Icons.more_vert, color: context.colors.textMain),
              color: context.colors.bgSecond,
              onSelected: (value) async {
                if (value == 'import') {
                  final changed = await startPackImport(context);
                  if (changed && mounted) _load();
                } else if (value == 'export') {
                  await startPackExport(context);
                }
              },
              itemBuilder: (menuContext) => [
                PopupMenuItem<String>(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_download_outlined, size: context.icon(20), color: context.colors.accent),
                      const SizedBox(width: 10),
                      Text(context.tr('qb.importZip'), style: TextStyle(color: context.colors.textMain)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload_outlined, size: context.icon(20), color: context.colors.accent),
                      const SizedBox(width: 10),
                      Text(context.tr('qb.exportZip'), style: TextStyle(color: context.colors.textMain)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: context.colors.accent,
            unselectedLabelColor: const Color(0xFF9E9E9E),
            indicatorColor: context.colors.accent,
            tabs: [
              Tab(text: context.tr('qb.tabQuestions')),
              Tab(text: context.tr('qb.tabPackages')),
              Tab(text: context.tr('qb.tabTemplates')),
              Tab(text: context.tr('qb.tabSessions')),
              Tab(text: context.tr('qb.tabTags')),
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
                  _buildSessionsTab(),
                  _buildTagsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildQuestionsTab() {
    if (_packages.isEmpty) {
      return Center(
        child: Text(context.tr('qb.noPackages'), style: TextStyle(color: Colors.grey[500])),
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
                        initialValue: selectedPackage['id'] as int,
                        items: _packages
                            .map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['title'] as String)))
                            .toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          setState(() => _selectedPackageId = id);
                          _loadQuestionsForSelectedPackage();
                        },
                        decoration: InputDecoration(
                          labelText: context.tr('qb.package'),
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
                label: Text(context.tr('menu.newQuestion')),
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
        child: Text(context.tr('qs.noQuestions'), style: TextStyle(color: Colors.grey[500])),
      );
    }
    final visible = _packageQuestions.where((q) => _matches(q.statement)).toList();
    if (visible.isEmpty) return _noResults();

    final tagNames = {for (final t in _tags) t['id'] as int: t['title'] as String};
    final templateNames = {
      for (final t in _templates)
        if (t.id != null) t.id!: t.name,
    };
    const cols = [('ID', 0), ('Enunciado', 6), ('Template', 2), ('Tag', 2)];

    return Column(
      children: [
        _tableHeader(cols),
        Expanded(
          child: ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, i) {
              final question = visible[i];
              final title = question.statement.isEmpty ? context.tr('qb.noStatement') : question.statement;
              return _tableRow(
                key: ValueKey(question.id ?? i),
                cells: [
                  ('${question.id ?? '-'}', 0),
                  (title, 6),
                  (templateNames[question.templateId] ?? '-', 2),
                  (question.tagId == null ? '-' : '#${tagNames[question.tagId] ?? '?'}', 2),
                ],
                menu: _itemMenu(
                  onEdit: () => _editQuestion(question),
                  onDelete: () => _deleteQuestion(question),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteQuestion(Question question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('qb.deleteQuestion')),
        content: Text(context.tr('qb.deleteQuestionBody', {'name': question.statement.isEmpty ? context.tr('qb.noStatement') : question.statement})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.delete'), style: const TextStyle(color: Color(0xFFC62828))),
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

  Widget _buildPackagesTab() {
    return Column(
      children: [
        Expanded(
          child: _query.isNotEmpty
              ? _buildPackageResults()
              : _packagesTable(_packages, reorderable: true),
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
                label: Text(context.tr('menu.newPackage')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPackageResults() {
    final results = _packages.where((p) => _matches(p['title'] as String)).toList();
    if (results.isEmpty) return _noResults();
    return _packagesTable(results, reorderable: false);
  }

  Widget _packagesTable(List<Map<String, dynamic>> rows, {required bool reorderable}) {
    const cols = [('ID', 0), ('Título', 6)];

    Widget row(Map<String, dynamic> pkg, int i) => _tableRow(
          key: ValueKey(pkg['id']),
          handle: reorderable ? _dragHandle(i) : null,
          cells: [('${pkg['id']}', 0), (pkg['title'] as String, 6)],
          menu: _itemMenu(
            onEdit: () => _editPackage(pkg),
            onExport: () => _exportPackage(pkg),
            onDelete: () => _deletePackage(pkg),
          ),
        );

    return _tableShell(
      header: _tableHeader(cols, handle: reorderable),
      list: reorderable
          ? ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: rows.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _packages.removeAt(oldIndex);
                  _packages.insert(newIndex, item);
                });
                _persistPackageOrder();
              },
              itemBuilder: (context, i) => row(rows[i], i),
            )
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => row(rows[i], i),
            ),
    );
  }

  Future<void> _deletePackage(Map<String, dynamic> pkg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('qb.deletePackage')),
        content: Text(context.tr('qb.deletePackageBody', {'name': '${pkg['title']}'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('common.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.delete'), style: const TextStyle(color: Color(0xFFC62828))),
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

  Widget _buildTemplatesTab() {
    return Column(
      children: [
        Expanded(
          child: _templates.isEmpty
              ? Center(child: Text(context.tr('qb.noTemplates'), style: TextStyle(color: Colors.grey[500])))
              : _query.isNotEmpty
                  ? _buildTemplateResults()
                  : _templatesTable(_templates, reorderable: true),
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
                label: Text(context.tr('menu.newTemplate')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateResults() {
    final results = _templates.where((t) => _matches(t.name)).toList();
    if (results.isEmpty) return _noResults();
    return _templatesTable(results, reorderable: false);
  }

  Widget _templatesTable(List<TemplateModel> rows, {required bool reorderable}) {
    const cols = [('ID', 0), ('Nome', 5), ('Campos', 2)];

    Widget row(TemplateModel t, int i) => _tableRow(
          key: ValueKey(t.id ?? t.name),
          handle: reorderable ? _dragHandle(i) : null,
          cells: [('${t.id ?? '-'}', 0), (t.name, 5), ('${t.fields.length}', 2)],
          menu: _itemMenu(
            onEdit: () => _editTemplate(t),
            onDelete: () => _deleteTemplate(t),
          ),
        );

    return _tableShell(
      header: _tableHeader(cols, handle: reorderable),
      list: reorderable
          ? ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: rows.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _templates.removeAt(oldIndex);
                  _templates.insert(newIndex, item);
                });
                _persistTemplateOrder();
              },
              itemBuilder: (context, i) => row(rows[i], i),
            )
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => row(rows[i], i),
            ),
    );
  }

  Widget _buildTagsTab() {
    final visible = _tags.where((t) => _matches(t['title'] as String)).toList();

    return Column(
      children: [
        Expanded(
          child: visible.isEmpty
              ? (_tags.isEmpty
                  ? Center(child: Text(context.tr('qb.noTags'), style: TextStyle(color: Colors.grey[500])))
                  : _noResults())
              : _tagsTable(visible),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await showNewTagDialog(context); 
                  if (mounted) _load(); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add),
                label: Text(context.tr('menu.newTag')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteTag(Map<String, dynamic> tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('qb.deleteTag')),
        content: Text(context.tr('qb.deleteTagBody', {'name': '${tag['title']}'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.delete'), style: const TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await QuestionDao().deleteTag(tag['id'] as int);
      _load();
    } catch (e) {
      debugPrint('Erro ao excluir tag ${tag['id']}: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('qb.deleteTagFailed', {'error': e}))),
      );
    }
  }

  Widget _buildSessionsTab() {
    final visible = _sessions.where((s) => _matches((s['title'] as String?) ?? '')).toList();
    return Column(
      children: [
        Expanded(
          child: visible.isEmpty
              ? (_sessions.isEmpty
                  ? Center(child: Text(context.tr('qb.noSessions'), style: TextStyle(color: Colors.grey[500])))
                  : _noResults())
              : _sessionsTable(visible),
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
                label: Text(context.tr('menu.newSession')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _sessionLimit(Map<String, dynamic> session) {
    final seconds = SessionDao.parseTimeLimitSeconds(session['time_limit'] as String?);
    return seconds == null ? context.tr('qb.noTimeLimit') : SessionDao.describeTimeLimit(seconds);
  }

  String _sessionFilters(Map<String, dynamic> session) {
    final filters = SessionDao.parseTagFilters(session['tag_filters'] as String?);
    if (filters.isEmpty) return '-';
    final names = {for (final t in _tags) t['id'] as int: t['title'] as String};
    return filters.map((f) => '#${names[f['tag_id']] ?? '?'} ${f['quantity']}').join(' · ');
  }

  Widget _sessionsTable(List<Map<String, dynamic>> rows) {
    const cols = [('ID', 0), ('Título', 4), ('Limite', 3), ('Questões', 2), ('Tags', 4)];
    return _tableShell(
      header: _tableHeader(cols),
      list: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final session = rows[i];
          return _tableRow(
            key: ValueKey(session['id']),
            cells: [
              ('${session['id']}', 0),
              ((session['title'] as String?) ?? 'Sessão ${session['id']}', 4),
              (_sessionLimit(session), 3),
              ('${(session['total_q'] as num?)?.toInt() ?? '-'}', 2),
              (_sessionFilters(session), 4),
            ],
            menu: _itemMenu(
              onEdit: () => _editSession(session),
              onDelete: () => _deleteSession(session),
            ),
          );
        },
      ),
    );
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
        title: Text(context.tr('qb.deleteSession')),
        content: Text(context.tr('qb.deleteSessionBody', {'name': '${session['title'] ?? ''}'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('common.delete'), style: const TextStyle(color: Color(0xFFC62828))),
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
        SnackBar(content: Text(context.tr('qb.deleteSessionFailed', {'error': e}))),
      );
    }
  }
}