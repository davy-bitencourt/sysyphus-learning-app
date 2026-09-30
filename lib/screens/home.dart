import 'package:flutter/material.dart';

import '../widgets/heatmap_card.dart';
import '../widgets/main_scaffold.dart';
import '../styles/text_styles.dart';
import '../data/DAO/package_dao.dart';
import '../data/schema/revlog_schema.dart';
import 'statistic_screen.dart';
import 'questions_screen.dart';
import 'package_edit_screen.dart';

class Home extends StatefulWidget {
  // TODO: substituir por um profile real assim que a tela de seleção
  // de perfil existir.
  final int profileId;

  /// Aviso de que a lista de pacotes mudou (criado, renomeado, excluído).
  /// Quem altera pacotes em outra tela faz `Home.packagesChanged.value++`.
  static final ValueNotifier<int> packagesChanged = ValueNotifier<int>(0);

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
    Home.packagesChanged.addListener(_onPackagesChanged);
    _loadData();
  }

  // Outra tela (ex: Banco de questões) criou/renomeou/excluiu um pacote.
  void _onPackagesChanged() => _loadData();

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
    Home.packagesChanged.removeListener(_onPackagesChanged);
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
      onItemCreated: _loadData,

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
      ],
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          // Área inteira do card é clicável agora, não só o texto do título.
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuestionScreen(packageId: deck.key),
              ),
            );
            if (mounted) _loadData(); // atualiza o heatmap com o que foi estudado
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(deck.value, style: mediumText),
                ),
                // Botão de configurações continua com sua própria área de
                // toque, sobrepondo a área clicável do card.
                IconButton(
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
                  icon: Icon(Icons.settings, color: Colors.grey[400], size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
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
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      // Toda a célula do título é clicável, não só o texto.
                      child: InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuestionScreen(packageId: deck.key),
                            ),
                          );
                          if (mounted) _loadData();
                        },
                        child: _tableCell(deck.value, const Color(0xFF1A1A2E)),
                      ),
                    ),
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