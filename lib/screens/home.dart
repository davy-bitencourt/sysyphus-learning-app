import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../styles/app_theme.dart';

import '../widgets/heatmap_card.dart';
import '../widgets/main_scaffold.dart';
import '../styles/text_styles.dart';
import '../data/DAO/package_dao.dart';
import '../data/DAO/question_state_dao.dart';
import '../data/schema/revlog_schema.dart';
import 'statistic_screen.dart';
import 'questions_screen.dart';
import 'package_edit_screen.dart';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;

class Home extends StatefulWidget {
  final int profileId;

  static final ValueNotifier<int> packagesChanged = ValueNotifier<int>(0);

  const Home({super.key, this.profileId = 1});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final RevlogSchema _revlogSchema = RevlogSchema();

  late final bool _isDesktop = switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
  };

  Map<int, String> _packages = {};
  Map<DateTime, int> _activityMap = {};
  int _newCount = 0; 
  int _dueCount = 0; 
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Home.packagesChanged.addListener(_onPackagesChanged);
    _loadData();
  }

  void _onPackagesChanged() => _loadData();

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final packageRows = await PackageDao().getAll();
    final heatmap = await _revlogSchema.getHeatmapData();
    final counts = await QuestionDao().getStudyCounts(_formatDate(DateTime.now()));

    if (!mounted) return;
    setState(() {
      _packages = {
        for (final row in packageRows) row['id'] as int: row['title'] as String
      };
      _activityMap = heatmap;
      _newCount = counts['new'] ?? 0;
      _dueCount = counts['due'] ?? 0;
      _loading = false;
    });
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    Home.packagesChanged.removeListener(_onPackagesChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: context.tr('nav.home'),
      currentIndex: _currentIndex,
      onTap: (i) => _pageController.jumpToPage(i),
      onStatisticsTap: () => _pageController.jumpToPage(1),
      onItemCreated: _loadData,

      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: [
          _isDesktop ? _buildDesktopBody() : _buildMobileBody(),
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
            const SizedBox(height: 12),
            _sectionLabel(context.tr('home.studyActivity')),
            HeatmapCard(activityMap: _activityMap, newCount: _newCount, dueCount: _dueCount),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel(context.tr('home.myPackages')),
              ],
            ),
            const SizedBox(height: 12),
            _buildDeckList(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                HeatmapCard(activityMap: _activityMap, newCount: _newCount, dueCount: _dueCount),
                const SizedBox(height: 24),
                if (_packages.isEmpty)
                  _noPackagesMessage(context.tr('home.createFirstDesktop'))
                else
                  _buildDeckTable(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _noPackagesMessage(String hint) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(context.tr('home.noPackages', {'hint': hint}), style: mediumText(fontWeight: FontWeight.normal, color: context.colors.textSecond)),
      );

  Widget _sectionLabel(String text) => Text(text, style: bigText(fontWeight: FontWeight.normal, color: context.colors.textMain));

  Widget _buildDeckList() {
    if (_packages.isEmpty) return _noPackagesMessage(context.tr('home.createFirstMobile'));
    return Column(
      children: _packages.entries.map(_buildDeckCard).toList(),
    );
  }

  Widget _buildDeckCard(MapEntry<int, String> deck) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: context.colors.bgSecond),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionScreen(packageId: deck.key)));
            if (mounted) _loadData();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(deck.value, style: mediumText(fontWeight: FontWeight.normal, color: context.colors.textMain)),
                ),
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
                  icon: Icon(Icons.settings, color: Colors.grey[400], size: context.icon(22)),
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
            color: context.colors.bgSecond,
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
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: context.colors.bgSecond))),
                children: [
                  _tableCell(context.tr('home.packagesHeader'), Colors.grey[400]!, isHeader: true),
                  const SizedBox(),
                ],
              ),
              ...List.generate(entries.length, (i) {
                final deck = entries[i];
                final isEven = i % 2 == 0;
                return TableRow(
                  decoration: BoxDecoration(
                    color: isEven ? context.colors.bgSecond : context.colors.bgSecond,
                  ),
                  children: [
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
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
                        child: _tableCell(deck.value, context.colors.textMain),
                      ),
                    ),
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.middle,
                      child: IconButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PackageEditScreen(packageId: deck.key,initialTitle: deck.value),
                            ),
                          );
                          if (result == true) _loadData();
                        },
                        icon: Icon(Icons.settings, size: context.icon(16), color: Colors.grey[400]),
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
        style: TextStyle(color: color, fontSize: isHeader ? 12 : 13, fontWeight: isHeader || bold ? FontWeight.bold : FontWeight.normal,)),
    );
  }
}