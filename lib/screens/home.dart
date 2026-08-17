import 'package:flutter/material.dart';

import '../widgets/heatmap_card.dart';
import '../widgets/main_scaffold.dart';
import '../styles/text_styles.dart';
import '../data/schema/package_schema.dart';
import '../data/schema/revlog_schema.dart';
import 'statistic_screen.dart';
import 'questions_screen.dart';

class Home extends StatefulWidget {
  // TODO: substituir por um profile real assim que a tela de seleção
  // de perfil existir. Por enquanto assume o profile de id 1.
  final int profileId;

  const Home({super.key, this.profileId = 1});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final PackageSchema _packageSchema = PackageSchema();
  final RevlogSchema _revlogSchema = RevlogSchema();

  Map<int, String> _packages = {};
  Map<DateTime, int> _activityMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    print('home está criado');
    _loadData();
  }

  Future<void> _loadData() async {
    print('1 - começou _loadData');
    setState(() => _loading = true);

    print('2 - buscando packages');
    await _packageSchema.getPackageDataByProfile(widget.profileId);

    print('3 - packages carregados');
    final heatmap = await _revlogSchema.getHeatmapData();

    print('4 - heatmap carregado');
    if (!mounted) return;

    setState(() {
      _packages = _packageSchema.package_schema;
      _activityMap = heatmap;
      _loading = false;
    });

    print('5 - loading false');
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
            _sectionLabel('My Packages'),
            const SizedBox(height: 12),
            _buildDeckList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

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
              _buildDesktopButton('New Package'),
              const SizedBox(width: 10),
              _buildDesktopButton('Add Question'),
              const SizedBox(width: 10),
              _buildDesktopButton('New Session'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopButton(String title) {
    return ElevatedButton.icon(
      onPressed: () {},
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
        child: Text('Nenhum pacote ainda para este profile.',
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
                onTap: () {}, // TODO: tela de configuração/edição do pacote
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
                        onPressed: () {},
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
