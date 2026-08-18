import 'package:flutter/material.dart';

import '../widgets/heatmap_card.dart';
import '../widgets/main_scaffold.dart';
import '../styles/text_styles.dart';
import '../data/DAO/package_dao.dart';
import '../data/DAO/tag_dao.dart';
import '../data/DAO/session_dao.dart';
import '../data/DTO/session_dto.dart';
import '../data/schema/revlog_schema.dart';
import 'statistic_screen.dart';
import 'questions_screen.dart';
import 'questions_edit_screen.dart';
import 'templaate_edit_screen.dart';
import 'package_edit_screen.dart';

class Home extends StatefulWidget {
  // TODO: substituir por um profile real assim que a tela de seleção
  // de perfil existir.
  final int profileId;

  const Home({super.key, this.profileId = 1});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final RevlogSchema _revlogSchema = RevlogSchema();

  Map<int, String> _packages = {};
  Map<DateTime, int> _activityMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    /* usa todos os pacotes por enquanto: o schema atual só liga um
     * profile a UM pacote (profile.package_id), o que não sustenta
     * uma lista de "meus pacotes" -- listar tudo aqui até a
     * modelagem de dono do pacote ser revista. */
    final packageRows = await PackageDao().getAll();
    final heatmap = await _revlogSchema.getHeatmapData();

    if (!mounted) return;
    setState(() {
      _packages = {
        for (final row in packageRows) row['id'] as int: row['title'] as String
      };
      _activityMap = heatmap;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Home',
      currentIndex: _currentIndex,
      onTap: (i) => _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
      onStatisticsTap: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: [
          _buildMobileBody(),
          const StatisticsScreen(),
        ],
      ),
    );
  }

  Widget _buildMobileBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            HeatmapCard(activityMap: _activityMap),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel('My Packages'),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFFE65100)),
                  onPressed: _showCreateMenu,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDeckList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Menu de criação (botão +)
  // ---------------------------------------------------------------

  Future<void> _showCreateMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _menuTile(Icons.folder_outlined, 'Novo pacote', 'package'),
            _menuTile(Icons.quiz_outlined, 'Nova questão', 'question'),
            _menuTile(Icons.dashboard_customize_outlined, 'Novo template', 'template'),
            _menuTile(Icons.label_outline, 'Nova tag', 'tag'),
            _menuTile(Icons.timer_outlined, 'Nova sessão', 'session'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    await _handleCreateAction(action);
  }

  Widget _menuTile(IconData icon, String label, String action) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE65100)),
      title: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
      onTap: () => Navigator.pop(context, action),
    );
  }

  Future<void> _handleCreateAction(String action) async {
    switch (action) {
      case 'package':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PackageEditScreen()),
        );
        if (result == true) _loadData();
        break;

      case 'question':
        // sem pacote pré-selecionado: o usuário escolhe dentro da tela
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuestionsEditScreen()),
        );
        break;

      case 'template':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TemplateEditScreen()),
        );
        break;

      case 'tag':
        await _showQuickTextDialog(
          title: 'Nova tag',
          hint: 'Nome da tag',
          onConfirm: (text) => TagDao().insert(text),
        );
        break;

      case 'session':
        await _showQuickTextDialog(
          title: 'Nova sessão',
          hint: 'Nome da sessão',
          onConfirm: (text) => SessionDao().insert(SessionDto(title: text)),
        );
        break;
    }
  }

  Future<void> _showQuickTextDialog({
    required String title,
    required String hint,
    required Future<void> Function(String text) onConfirm,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    final text = controller.text.trim();
    if (confirmed == true && text.isNotEmpty) {
      await onConfirm(text);
    }
  }

  // ---------------------------------------------------------------
  // Desktop
  // ---------------------------------------------------------------

  Widget _buildDesktopBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                HeatmapCard(activityMap: _activityMap),
                const SizedBox(height: 24),
                _buildDeckTable(),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDesktopButton('New Package', () => _handleCreateAction('package')),
              const SizedBox(width: 10),
              _buildDesktopButton('Add Question', () => _handleCreateAction('question')),
              const SizedBox(width: 10),
              _buildDesktopButton('New Session', () => _handleCreateAction('session')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopButton(String title, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A2E)));

  Widget _buildDeckList() {
    if (_packages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('Nenhum pacote ainda. Toque no + para criar o primeiro.',
          style: TextStyle(color: Colors.grey[500])),
      );
    }
    return Column(
      children: _packages.entries.map(_buildDeckCard).toList(),
    );
  }

  Widget _buildDeckCard(MapEntry<int, String> deck) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestionScreen(packageId: deck.key),
                    ),
                  ),
                  child: Text(deck.value, style: mediumText),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PackageEditScreen(
                        packageId: deck.key,
                        initialTitle: deck.value,
                      ),
                    ),
                  );
                  if (result == true) _loadData();
                },
                child: Icon(Icons.settings, color: Colors.grey[400], size: 22),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildDeckTable() {
    final entries = _packages.entries.toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FixedColumnWidth(40),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
                children: [
                  _tableCell('Packages', Colors.grey[400]!, isHeader: true),
                  const SizedBox(),
                ],
              ),
              ...List.generate(entries.length, (i) {
                final deck = entries[i];
                final isEven = i % 2 == 0;
                return TableRow(
                  decoration: BoxDecoration(
                    color: isEven ? const Color(0xFFFFFFFF) : const Color(0xFFF5F5F5),
                  ),
                  children: [
                    _tableCell(deck.value, const Color(0xFF1A1A2E)),
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: IconButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PackageEditScreen(
                                packageId: deck.key,
                                initialTitle: deck.value,
                              ),
                            ),
                          );
                          if (result == true) _loadData();
                        },
                        icon: Icon(Icons.settings, size: 16, color: Colors.grey[400]),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableCell(String text, Color color, {
    bool isHeader = false,
    bool center = false,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: color,
          fontSize: isHeader ? 12 : 13,
          fontWeight: isHeader || bold ? FontWeight.bold : FontWeight.normal,
        )),
    );
  }
}
