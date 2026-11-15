import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../styles/app_theme.dart';

import '../widgets/heatmap_card.dart';
import '../widgets/main_scaffold.dart';
import '../data/DAO/package_dao.dart';
import '../data/DAO/question_state_dao.dart';
import '../widgets/quick_subject_dialog.dart';
import '../data/services/order_service.dart';
import '../data/schema/revlog_schema.dart';
import 'statistic_screen.dart';
import 'questions_screen.dart';
import 'package_edit_screen.dart';
import 'questions_edit_screen.dart';
import 'question_bank_screen.dart';


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

  // A largura, não o sistema operacional, determina o layout responsivo.
  bool get _isDesktop => MediaQuery.sizeOf(context).width >= 720;

  Map<int, String> _packages = {};
  Map<int, int> _packageCounts = {};
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
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

    final packageRows = await OrderService.apply(
        OrderService.packagesKey, await PackageDao().getAll(), (p) => p['id'] as int);
    final packageCounts = await QuestionDao().getPackageCounts();
    final heatmap = await _revlogSchema.getHeatmapData();
    final counts = await QuestionDao().getStudyCounts(_formatDate(DateTime.now()));

    if (!mounted) return;
    setState(() {
      _packages = {
        for (final row in packageRows) row['id'] as int: row['title'] as String
      };
      _packageCounts = packageCounts;
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
    _searchController.dispose();
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

  Future<void> _createPackage() async {
    final result = await showQuickSubjectDialog(context);
    if (result == null || !mounted) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('ux.subjectCreated'))),
    );
    if (result.addQuestion) await _addQuestion(result.id);
  }

  Future<void> _editPackage(int id, String title) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PackageEditScreen(
        packageId: id, initialTitle: title,
      )),
    );
    if (changed == true && mounted) await _loadData();
  }

  Future<void> _deletePackage(int id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('pkg.deleteTitle')),
        content: Text(context.tr('pkg.deleteBody', {'title': title})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('pkg.deleteAll')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await QuestionDao().deletePackageCascade(id);
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('ux.subjectDeleted'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('pkg.deleteFailed', {'error': error}))),
      );
    }
  }

  Future<void> _addQuestion(int packageId) async {
    final result = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => QuestionsEditScreen(packageId: packageId)),
    );
    if (result == true && mounted) await _loadData();
  }

  Future<void> _manageQuestions(int packageId) async {
    await Navigator.push(
      context, MaterialPageRoute(builder: (_) => QuestionBankScreen(initialPackageId: packageId)),
    );
    if (mounted) await _loadData();
  }

  Future<void> _studyPackage(int packageId) async {
    await Navigator.push(
      context, MaterialPageRoute(builder: (_) => QuestionScreen(packageId: packageId)),
    );
    if (mounted) await _loadData();
  }

  Widget _newPackageButton() => TextButton.icon(
    onPressed: _createPackage,
    icon: const Icon(Icons.add),
    label: Text(context.tr('ux.newSubject')),
  );

  Widget _packageSearch() => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 12),
    child: TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isEmpty ? null : IconButton(
          tooltip: context.tr('qb.closeSearch'),
          icon: const Icon(Icons.close),
          onPressed: () {
            _searchController.clear();
            setState(() => _search = '');
          },
        ),
        hintText: context.tr('ux.searchSubjects'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  List<MapEntry<int, String>> get _visiblePackages => _packages.entries
      .where((entry) => entry.value.toLowerCase().contains(_search))
      .toList();

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
                _newPackageButton(),
              ],
            ),
            _packageSearch(),
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
                Row(
                  children: [
                    Expanded(child: _sectionLabel(context.tr('home.myPackages'))),
                    _newPackageButton(),
                  ],
                ),
                _packageSearch(),
                _buildDeckList(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _noPackagesMessage(String hint) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.library_books_outlined, size: 44, color: context.colors.textSecond),
        const SizedBox(height: 10),
        Text(context.tr('ux.emptySubjects'), textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textMain, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(hint, textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecond)),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _createPackage,
          icon: const Icon(Icons.add),
          label: Text(context.tr('ux.newSubject')),
        ),
      ]),
    ),
  );

  Widget _sectionLabel(String text) => Text(text, style: bigText(fontWeight: FontWeight.bold, color: context.colors.textMain));

  Widget _buildDeckList() {
    if (_packages.isEmpty) return _noPackagesMessage(context.tr('ux.emptySubjectsHint'));
    if (_visiblePackages.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(context.tr('ux.noMatches')),
      ));
    }
    return Column(children: _visiblePackages.map(_buildDeckCard).toList());
  }

  Widget _buildDeckCard(MapEntry<int, String> deck) {
    final count = _packageCounts[deck.key] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: context.colors.bgSecond,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(deck.value,
              style: mediumText(fontWeight: FontWeight.bold, color: context.colors.textMain))),
            PopupMenuButton<String>(
              tooltip: context.tr('common.options'),
              onSelected: (value) {
                if (value == 'edit') _editPackage(deck.key, deck.value);
                if (value == 'delete') _deletePackage(deck.key, deck.value);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(context.tr('pkg.edit'))),
                PopupMenuItem(value: 'delete', child: Text(context.tr('pkg.deleteTitle'))),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.quiz_outlined, size: 17, color: context.colors.textSecond),
            const SizedBox(width: 6),
            Text(context.tr('ux.questionCount', {'count': count}),
              style: TextStyle(color: context.colors.textSecond)),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final add = OutlinedButton.icon(
              onPressed: () => _addQuestion(deck.key),
              icon: const Icon(Icons.add),
              label: Text(context.tr('ux.addQuestion')),
            );
            final study = ElevatedButton.icon(
              onPressed: count == 0 ? null : () => _studyPackage(deck.key),
              icon: const Icon(Icons.play_arrow),
              label: Text(context.tr('ux.study')),
            );
            if (constraints.maxWidth < 430) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                add, study,
              ]);
            }
            return Row(children: [
              Expanded(child: add),
              const SizedBox(width: 8),
              Expanded(child: study),
            ]);
          }),
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () => _manageQuestions(deck.key),
            icon: const Icon(Icons.list_alt_outlined),
            label: Text(context.tr('ux.manageQuestions')),
          )),
        ]),
      ),
    );
  }
}
