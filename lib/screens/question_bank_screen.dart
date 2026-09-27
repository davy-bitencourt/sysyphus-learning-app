import 'package:flutter/material.dart';

import '../data/DAO/package_dao.dart';
import '../data/DAO/template_dao.dart';
import '../data/models/field_model.dart';
import 'package_edit_screen.dart';
import 'questions_screen.dart';
import 'templaate_edit_screen.dart';

/// Tela de gerenciamento do banco de questões e templates da aplicação.
///
/// Acessada pelo item "Questions finder" do menu lateral. Reúne, em duas
/// abas, todos os pacotes (com atalho para ver/editar suas questões) e
/// todos os templates cadastrados.
class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  List<Map<String, dynamic>> _packages = [];
  List<TemplateModel> _templates = [];
  bool _loading = true;

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
  }

  Future<void> _openNewTemplate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Banco de questões',
            style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 20)),
          bottom: const TabBar(
            labelColor: Color(0xFFE65100),
            unselectedLabelColor: Color(0xFF9E9E9E),
            indicatorColor: Color(0xFFE65100),
            tabs: [
              Tab(text: 'Pacotes'),
              Tab(text: 'Templates'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildPackagesTab(),
                  _buildTemplatesTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildPackagesTab() {
    if (_packages.isEmpty) {
      return Center(
        child: Text('Nenhum pacote cadastrado ainda.', style: TextStyle(color: Colors.grey[500])),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final pkg = _packages[i];
        final id = pkg['id'] as int;
        final title = pkg['title'] as String;
        return Material(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => QuestionScreen(packageId: id)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
                  ),
                  IconButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PackageEditScreen(packageId: id, initialTitle: title),
                        ),
                      );
                      if (result == true) _load();
                    },
                    icon: Icon(Icons.settings, size: 18, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
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
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.dashboard_customize_outlined,
                            color: Color(0xFFE65100), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(template.name,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
                          ),
                          Text('${template.fields.length} campos',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
                  backgroundColor: const Color(0xFFE65100),
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
