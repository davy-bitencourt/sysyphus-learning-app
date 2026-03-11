import 'package:flutter/material.dart';

import '../widgets/heatmap_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/main_scaffold.dart';

import '../styles/text_styles.dart';

import 'statistic_screen.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;

  final List<Map<String, String>> _decks = [
    {'title': 'Concurso da Polícia Militar', 'lastReview': 'Última revisão há 30 dias'},
    {'title': 'Curso de Proficiência em Inglês', 'lastReview': 'Última revisão há 4 dias'},
    {'title': 'Questões do Vestibular da UFMS (2000 - 2020)', 'lastReview': 'Última revisão há 2 dias'},
    {'title': 'Questões de Gramática em Francês', 'lastReview': 'Última revisão há 1 mês'},
  ];

  Map<DateTime, int> _buildActivityMap() {
    final map = <DateTime, int>{};
    final today = DateTime.now();
    final pattern = [0, 1, 2, 3, 4, 2, 1, 3, 0, 4, 2, 1, 3, 2, 4, 0, 1, 2];
    for (int i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      map[DateTime(d.year, d.month, d.day)] = pattern[i % pattern.length];
    }
    return map;
  }

  static bool _isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600;

  //Build principal
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    print(" W:${size.width} | H:${size.height}");

    final desktop = _isDesktop(context);
    return MainScaffold(
      title: "Home",
      body: IndexedStack(
        index: _currentIndex, // vem do BottomNav
        children: [
          desktop ? _buildDesktopBody() : _buildMobileBody(),
          const StatisticsScreen(),
        ],
      ),
      bottomNavigationBar: desktop ? null : BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
      floatingActionButton: desktop ? null : _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildMobileBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          HeatmapCard(activityMap: _buildActivityMap()),          
          const SizedBox(height: 20),
          _sectionLabel('My Packages'),
          const SizedBox(height: 12),
          _buildDeckList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDesktopButton(String title){
    return ElevatedButton.icon(
              onPressed: () {},
              label: Text(title),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ); 
  }

  Widget _buildDesktopBody() {
  return Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // _sectionLabel('My Latest Review'),
              const SizedBox(height: 10),
              HeatmapCard(activityMap: _buildActivityMap()),
              const SizedBox(height: 24),
              // const SizedBox(height: 12),
              _buildDeckTable(),
            ],
          ),
        ),
      ),

      // Footer
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
 
  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A2E)));
  Widget _buildDeckList() => Column(children: _decks.map(_buildDeckCard).toList());

  Widget _buildDeckCard(Map<String, String> deck) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(
                  child: Text(deck['title']!, style: mediumText),
                ),

                Icon(Icons.settings, color: Colors.grey[400], size: 22),
             ],
            ),

            const SizedBox(height: 4),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(deck['lastReview']!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ]),

              Wrap(spacing: 6, children: [
                _buildTag('60', const Color(0xFF1565C0)),
                _buildTag('10', const Color(0xFFC62828)),
              ]),
            ],)

          ]),
        ),
      ]),
    );
  }

Widget _buildDeckTable() {
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
            0: FlexColumnWidth(),   // título — ocupa o resto
            1: FixedColumnWidth(100), // Novo
            2: FixedColumnWidth(100), // Reforço
            3: FixedColumnWidth(40), // engrenagem
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0)))),
              children: [
                _tableCell('Packages', Colors.grey[400]!, isHeader: true),
                _tableCell('Novo',     Colors.grey[400]!, isHeader: true, center: true),
                _tableCell('Reforço',  Colors.grey[400]!, isHeader: true, center: true),
                const SizedBox(),
              ],
            ),
            ...List.generate(_decks.length, (i) {
              final deck = _decks[i];
              final isEven = i % 2 == 0;
              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? const Color(0xFFFFFFFF) : const Color(0xFFF5F5F5),
                ),
                children: [
                  _tableCell(deck['title']!, const Color(0xFF1A1A2E)),
                  _tableCell('60', const Color(0xFF1565C0), center: true, bold: true),
                  _tableCell('20', const Color(0xFFE65100), center: true, bold: true),
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
  // Widgets pequenos
  Widget _buildTag(String cont, Color color) {
    return Text(cont,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500));
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: const Color(0xFFE65100),
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    );
  }
}