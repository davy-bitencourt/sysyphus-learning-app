import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedTab = 0;

  final List<Map<String, String>> _decks = [
    {'title': 'Concurso da Polícia Militar', 'lastReview': 'Última revisão há 30 dias'},
    {'title': 'Curso de Proficiência em Inglês', 'lastReview': 'Última revisão há 4 dias'},
    {'title': 'Questões do Vestibular da UFMS (2000 - 2020)', 'lastReview': 'Última revisão há 2 dias'},
    {'title': 'Questões de Gramática em Francês', 'lastReview': 'Última revisão há 1 mês'},
  ];

  /// Replace with real data: Map of normalized date -> review intensity (0-4)
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

  Color _heatColor(int value) {
    switch (value) {
      case 1:  return const Color(0xFF9BE9A8);
      case 2:  return const Color(0xFF40C463);
      case 3:  return const Color(0xFF30A14E);
      case 4:  return const Color(0xFF216E39);
      default: return const Color(0xFFEBEDF0);
    }
  }

  static bool _isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600;

  @override
  Widget build(BuildContext context) {
    final desktop = _isDesktop(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: _buildAppBar(desktop),
      body: desktop ? _buildDesktopBody() : _buildMobileBody(),
      bottomNavigationBar: desktop ? null : _buildBottomNav(),
      floatingActionButton: desktop ? null : _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  PreferredSizeWidget _buildAppBar(bool desktop) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 160,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          const Text('Sysyphus',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E), letterSpacing: 1.2)),
        ]),
      ),
      actions: [
        if (desktop) ...[
          TextButton(onPressed: () {},
            child: const Text('Home',
              style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold))),
          TextButton(onPressed: () {},
            child: Text('Statistics', style: TextStyle(color: Colors.grey[500]))),
          const SizedBox(width: 8),
        ],
        IconButton(icon: const Icon(Icons.sync, color: Color(0xFF555555)), onPressed: () {}),
        IconButton(icon: const Icon(Icons.menu, color: Color(0xFF555555)), onPressed: () {}),
      ],
    );
  }

  // ── Mobile ─────────────────────────────────────────────────────────────────

  Widget _buildMobileBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 20),
          _sectionLabel('My Latest Review'),
          const SizedBox(height: 10),
          _buildHeatmapCard(),
          const SizedBox(height: 20),
          _buildTabBar(),
          const SizedBox(height: 12),
          _buildDeckList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────────

  Widget _buildDesktopBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 220,
          height: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Menu',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: Colors.grey[400], letterSpacing: 1)),
              ),
              _sidebarItem(Icons.home_outlined,      'Home',       true),
              _sidebarItem(Icons.bar_chart_outlined,  'Statistics', false),
              _sidebarItem(Icons.settings_outlined,   'Settings',   false),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Deck'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchBar(),
                const SizedBox(height: 24),
                _sectionLabel('My Latest Review'),
                const SizedBox(height: 12),
                _buildHeatmapCard(),
                const SizedBox(height: 24),
                _buildTabBar(),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3.8,
                  ),
                  itemCount: _decks.length,
                  itemBuilder: (_, i) => _buildDeckCard(_decks[i]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sidebarItem(IconData icon, String label, bool active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF1565C0).withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 18,
          color: active ? const Color(0xFF1565C0) : Colors.grey[500]),
        title: Text(label,
          style: TextStyle(fontSize: 13,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? const Color(0xFF1565C0) : Colors.grey[700])),
        onTap: () {},
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A2E)));

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ── Heatmap ────────────────────────────────────────────────────────────────
  //
  // FIX: Container (padding) is the OUTER widget.
  // LayoutBuilder is the INNER child — so constraints.maxWidth already
  // reflects the width AFTER the 16px padding on each side is consumed.
  // availW only subtracts dayLabelW + labelGap. Nothing else.

  Widget _buildHeatmapCard() {
    const double cellSize  = 11;
    const double cellGap   = 2;
    const double cellStep  = cellSize + cellGap; // 13 px per column slot
    const double dayLabelW = 26;
    const double labelGap  = 4;

    final today       = DateTime.now();
    final todayNorm   = DateTime(today.year, today.month, today.day);
    final activityMap = _buildActivityMap();
    final monthNames  = ['Jan','Feb','Mar','Apr','May','Jun',
                         'Jul','Aug','Sep','Oct','Nov','Dec'];

    final thisMonday = todayNorm.subtract(Duration(days: todayNorm.weekday - 1));

    // Container is OUTSIDE — its padding runs before LayoutBuilder measures
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        // constraints.maxWidth == inner width (padding already subtracted by Flutter)
        final double availW   = constraints.maxWidth - dayLabelW - labelGap;
        final int visibleCols = availW ~/ cellStep; // whole columns only

        final int colsBefore      = visibleCols ~/ 2;
        final DateTime firstMonday =
            thisMonday.subtract(Duration(days: colsBefore * 7));

        // Exact grid width: drop the last trailing gap
        final double gridW = visibleCols * cellStep - cellGap;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Study Activity',
                    style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text('365 cards reviewed this year',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF216E39).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('🔥 12 day streak',
                    style: TextStyle(fontSize: 11, color: Color(0xFF216E39),
                      fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Day labels + grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: dayLabelW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(height: 14),
                      ...List.generate(7, (i) {
                        final label = i == 0 ? 'Mon'
                            : i == 2 ? 'Wed'
                            : i == 4 ? 'Fri'
                            : '';
                        return SizedBox(
                          height: cellStep,
                          child: Text(label,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 7, color: Colors.grey[400])),
                        );
                      }),
                    ],
                  ),
                ),
                SizedBox(width: labelGap),

                // Pixel-exact grid
                SizedBox(
                  width: gridW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 14,
                        child: Stack(
                          children: List.generate(visibleCols, (ci) {
                            final monday = firstMonday.add(Duration(days: ci * 7));
                            String? label;
                            for (int d = 0; d < 7; d++) {
                              final day = monday.add(Duration(days: d));
                              if (day.day == 1) {
                                label = monthNames[day.month - 1];
                                break;
                              }
                            }
                            if (label == null) return const SizedBox.shrink();
                            return Positioned(
                              left: ci * cellStep,
                              child: Text(label,
                                style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                            );
                          }),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(visibleCols, (ci) {
                          final monday = firstMonday.add(Duration(days: ci * 7));
                          return SizedBox(
                            width: cellStep, // fixed slot — no flex
                            child: Column(
                              children: List.generate(7, (d) {
                                final date    = monday.add(Duration(days: d));
                                final dateKey = DateTime(date.year, date.month, date.day);
                                final isToday  = dateKey == todayNorm;
                                final isFuture = date.isAfter(todayNorm);
                                final value    = isFuture ? 0 : (activityMap[dateKey] ?? 0);
                                return Container(
                                  width: cellSize, height: cellSize,
                                  margin: const EdgeInsets.only(bottom: cellGap),
                                  decoration: BoxDecoration(
                                    color: isFuture
                                        ? const Color(0xFFF0F0F0)
                                        : _heatColor(value),
                                    borderRadius: BorderRadius.circular(2),
                                    border: isToday
                                        ? Border.all(
                                            color: const Color(0xFF1565C0),
                                            width: 1.5)
                                        : null,
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Text('Less', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                  const SizedBox(width: 4),
                  ...[0, 1, 2, 3, 4].map((v) => Container(
                    width: 9, height: 9,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: _heatColor(v), borderRadius: BorderRadius.circular(2)),
                  )),
                  Text('More', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                ]),
                Row(children: [
                  _buildStatChip('60', 'New',    const Color(0xFF1565C0)),
                  const SizedBox(width: 6),
                  _buildStatChip('20', 'Learn',  const Color(0xFFE65100)),
                  const SizedBox(width: 6),
                  _buildStatChip('10', 'Review', const Color(0xFF216E39)),
                ]),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C2C54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Continue Learning', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Decks ──────────────────────────────────────────────────────────────────

  Widget _buildDeckList() => Column(children: _decks.map(_buildDeckCard).toList());

  Widget _buildDeckCard(Map<String, String> deck) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(deck['title']!,
              style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(deck['lastReview']!,
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _buildTag('60 New'),
              _buildTag('20 Learning'),
              _buildTag('10 Reviewing'),
            ]),
          ]),
        ),
        Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 24),
      ]),
    );
  }

  Widget _buildStatChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
      child: Text('$count $label',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label,
        style: const TextStyle(fontSize: 10, color: Colors.grey,
          fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildTabBar() {
    return Row(children: [
      _buildTab('My Decks', 0),
      const SizedBox(width: 24),
      _buildTab('Imported Decks', 1),
    ]);
  }

  Widget _buildTab(String title, int index) {
    final sel = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: TextStyle(fontSize: 14,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              color: sel ? const Color(0xFF1A1A2E) : Colors.grey[400])),
          const SizedBox(height: 4),
          if (sel)
            Container(height: 2, width: title.length * 7.5,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined,      'Home',       true),
            const SizedBox(width: 48),
            _buildNavItem(Icons.bar_chart_outlined, 'Statistics', false),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon,
          color: isActive ? const Color(0xFF1565C0) : Colors.grey[400], size: 24),
        Text(label,
          style: TextStyle(fontSize: 11,
            color: isActive ? const Color(0xFF1565C0) : Colors.grey[400])),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: const Color(0xFF2C2C54),
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    );
  }
}