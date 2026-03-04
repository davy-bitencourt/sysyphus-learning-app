import 'package:flutter/material.dart';

/// [Home] é um StatefulWidget porque precisa manter o estado da aba
/// selecionada (_selectedTab) e reagir a mudanças de layout (mobile/desktop).
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  /// Controla qual aba está ativa (0 = My Decks, 1 = Imported Decks).
  /// Usa int em vez de enum por simplicidade — só dois estados possíveis.
  int _selectedTab = 0;

  /// Lista de decks exibidos. Cada item é um Map simples com título e
  /// data da última revisão. Em produção, seria uma lista de objetos tipados.
  final List<Map<String, String>> _decks = [
    {'title': 'Concurso da Polícia Militar', 'lastReview': 'Última revisão há 30 dias'},
    {'title': 'Curso de Proficiência em Inglês', 'lastReview': 'Última revisão há 4 dias'},
    {'title': 'Questões do Vestibular da UFMS (2000 - 2020)', 'lastReview': 'Última revisão há 2 dias'},
    {'title': 'Questões de Gramática em Francês', 'lastReview': 'Última revisão há 1 mês'},
  ];

  /// Constrói um mapa de datas → intensidade de atividade (0–4) para o heatmap.
  /// Por ora usa um padrão cíclico fixo; em produção viria de um banco de dados.
  /// DateTime(year, month, day) normaliza a chave, removendo o componente de hora.
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

  /// Retorna a cor do quadradinho do heatmap de acordo com o nível de atividade.
  /// Segue a paleta do GitHub Contributions Graph (verde escalonado).
  Color _heatColor(int value) {
    switch (value) {
      case 1:  return const Color(0xFF9BE9A8); // verde muito claro
      case 2:  return const Color(0xFF40C463); // verde médio
      case 3:  return const Color(0xFF30A14E); // verde forte
      case 4:  return const Color(0xFF216E39); // verde escuro
      default: return const Color(0xFFEBEDF0); // cinza (sem atividade)
    }
  }

  /// Breakpoint simples: ≥ 600px de largura é tratado como desktop/tablet.
  /// Evita importar pacotes externos de responsividade para algo tão direto.
  static bool _isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600;

  //Build principal
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    print(size.width);  // largura
    print(size.height); // altura 

    final desktop = _isDesktop(context);
    return Scaffold(
      // Cor de fundo neutra que contrasta com os cards brancos.
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: _buildAppBar(desktop),
      // Escolhe o layout baseado no breakpoint.
      body: desktop ? _buildDesktopBody() : _buildMobileBody(),
      // BottomNav e FAB só fazem sentido no mobile; no desktop usa sidebar.
      bottomNavigationBar: desktop ? null : _buildBottomNav(),
      floatingActionButton: desktop ? null : _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  /// AppBar compartilhado entre mobile e desktop.
  /// No desktop exibe links de navegação em texto; no mobile só ícones.
  /// leadingWidth ampliado para comportar logo + nome do app.
PreferredSizeWidget _buildAppBar(bool desktop) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    automaticallyImplyLeading: false,
    title: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.menu, color: Color(0xFF555555)), onPressed: () {}),

          const SizedBox(width: 10),

          const Text('Sysyphus',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, 
            color: Color(0xFF1A1A2E))),
        ]),

        IconButton(icon: const Icon(Icons.sync, color: Color(0xFF555555)), onPressed: () {}),
      ],
    ),
  );
}

  // ── Mobile ─────────────────────────────────────────────────────────────────

  /// Layout mobile: tudo em coluna única, rolagem vertical.
  /// SingleChildScrollView com padding para não conflitar com a BottomNav + FAB.
  Widget _buildMobileBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // _sectionLabel('My Latest Review'),
          const SizedBox(height: 10),
          _buildHeatmapCard(),
          const SizedBox(height: 20),
          _sectionLabel('My Packages'),
          const SizedBox(height: 12),
          // _buildDeckList usa Column internamente — sem altura fixa, sem overflow.
          _buildDeckList(),
          // Espaço extra para não ficar atrás da BottomNav/FAB.
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Desktop ────────────────────────────────────────────────────────────────


  int _deckColumns(double width) {
    if (width >= 870) return 3;
    if (width >= 600) return 2;
    return 1;
  }
  /// Layout desktop: sidebar fixa à esquerda + área de conteúdo à direita.
  /// Row de nível superior; a sidebar tem altura infinita para preencher a tela.
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
              _buildHeatmapCard(),
              const SizedBox(height: 24),
              _sectionLabel('My Packages'),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = _deckColumns(constraints.maxWidth);
                  final double cardWidth = (constraints.maxWidth - 12 * (cols - 1)) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _decks.map((deck) => SizedBox(
                      width: cardWidth,
                      child: _buildDeckCard(deck),
                    )).toList(),
                  );
                },
              ),
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
            ElevatedButton.icon(
              onPressed: () {},
              label: const Text('New Package'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C54),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ), const SizedBox(width: 10),

            ElevatedButton.icon(
              onPressed: () {},
              label: const Text('Add Question'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C54),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ), const SizedBox(width: 10),
            
            ElevatedButton.icon(
              onPressed: () {},
              label: const Text('New Session'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C54),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}



  // ── Sidebar item ───────────────────────────────────────────────────────────

  /// Item de navegação da sidebar com destaque visual quando ativo.
  /// ListTile dense reduz o padding vertical padrão, adequado para sidebars.
  Widget _sidebarItem(IconData icon, String label, bool active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        // Fundo levemente colorido indica seleção sem ser intrusivo.
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

  // ── Utilitários de layout ──────────────────────────────────────────────────
  /// Rótulo de seção padronizado — reutilizado em vários pontos da tela.
  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A2E)));

  // ── Heatmap ────────────────────────────────────────────────────────────────
  //
  // Arquitetura de medição:
  //   Container (padding: 16) → LayoutBuilder → mede largura INTERNA
  //   availW = constraints.maxWidth - dayLabelW - labelGap
  //   visibleCols = availW ~/ cellStep  (truncado → sem overflow horizontal)
  //   gridW = visibleCols * cellStep - cellGap  (remove gap do último slot)
  //
  // Container externo já absorve o padding antes do LayoutBuilder medir,
  // então constraints.maxWidth reflete a área útil corretamente.

  Widget _buildHeatmapCard() {
    const double cellSize  = 11;
    const double cellGap   = 2;
    const double cellStep  = cellSize + cellGap;
    const double dayLabelW = 26;
    const double labelGap  = 4;

    final today       = DateTime.now();
    final todayNorm   = DateTime(today.year, today.month, today.day);
    final activityMap = _buildActivityMap();
    final monthNames  = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    final thisMonday = todayNorm.subtract(Duration(days: todayNorm.weekday - 1));

    return Center(
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800),
      child: Container(
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
        final double availW   = constraints.maxWidth - dayLabelW - labelGap;
        final int visibleCols = (availW / cellStep).floor();
        final int colsBefore  = visibleCols ~/ 2;
        final DateTime firstMonday = thisMonday.subtract(Duration(days: colsBefore * 7));
        final double gridW = visibleCols * (cellSize + cellGap);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Study Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('365 questions this day', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Text('12 day streak', style: TextStyle(fontSize: 11, color: Color(0xFF216E39), fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 5),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: dayLabelW,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const SizedBox(height: 14),
                  ...List.generate(7, (i) {
                    final label = i == 0 ? 'Mon' : i == 2 ? 'Wed' : i == 4 ? 'Fri' : '';
                    return SizedBox(
                      height: cellStep,
                      child: Text(label,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 7, color: Colors.grey[400])),
                    );
                  }),
                ]),
              ),
              SizedBox(width: labelGap),

              ClipRect(
                child: SizedBox(
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
                              if (day.day == 1) { label = monthNames[day.month - 1]; break; }
                            }
                            if (label == null) return const SizedBox.shrink();
                            return Positioned(
                              left: ci * cellStep.toDouble(),
                              child: Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                            );
                          }),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(visibleCols, (ci) {
                          final monday = firstMonday.add(Duration(days: ci * 7));
                          return Padding(
                            padding: const EdgeInsets.only(right: cellGap),
                            child: Column(
                              children: List.generate(7, (d) {
                                final date    = monday.add(Duration(days: d));
                                final dateKey = DateTime(date.year, date.month, date.day);
                                final isToday  = dateKey == todayNorm;
                                final isFuture = date.isAfter(todayNorm);
                                final value = isFuture ? 0 : (activityMap[dateKey] ?? 0);
                                return Container(
                                  width: cellSize, height: cellSize,
                                  margin: const EdgeInsets.only(bottom: cellGap),
                                  decoration: BoxDecoration(
                                    color: isFuture ? const Color(0xFFF0F0F0) : _heatColor(value),
                                    borderRadius: BorderRadius.circular(2),
                                    border: isToday ? Border.all(color: const Color(0xFF1565C0), width: 1.5) : null,
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
              ),
            ]),
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
                    decoration: BoxDecoration(color: _heatColor(v), borderRadius: BorderRadius.circular(2)),
                  )),
                  Text('More', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                ]),
                Row(children: [
                  _buildStatChip('60', const Color(0xFF1565C0)),
                  const SizedBox(width: 6),
                  _buildStatChip('10', const Color(0xFFC62828)),
                  const SizedBox(width: 10),
                ]),
              ],
            ),
            const SizedBox(height: 12),
          ],
        );
      }),
    ),), 
    );
  }

  // ── Decks ──────────────────────────────────────────────────────────────────

  /// Lista de cards para o mobile — Column sem restrição de altura.
  Widget _buildDeckList() => Column(children: _decks.map(_buildDeckCard).toList());

  /// Card de deck individual.
  /// Container com padding e BoxShadow em vez de Card para controle total
  /// do visual sem herdar elevação ou cor de superfície do tema.
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
        // Expanded garante que o texto não transborde horizontalmente.
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(
                  child: Text(deck['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E))),
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

              // Wrap permite que as tags quebrem para a próxima linha se não
              // couberem na largura disponível — mais robusto que Row fixo.
              Wrap(spacing: 6, children: [
                _buildTag('60', const Color(0xFF1565C0)),
                _buildTag('10', const Color(0xFFC62828)),
              ]),
            ],)

          ]),
        ),
        // Ícone de expansão — sinalizador visual de que o card é interativo.
      ]),
    );
  }

  // ── Widgets pequenos ───────────────────────────────────────────────────────

  /// Chip colorido para estatísticas (Nova / Learn / Review).
  /// Fundo com opacidade reduzida evita vibração de cor; texto usa a cor plena.
  Widget _buildStatChip(String count, Color color) {
    return Text(count,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600));
  }

  /// Tag de categoria dos cards dentro do deck.
  /// Fundo cinza neutro para não disputar atenção com as estatísticas coloridas.
  Widget _buildTag(String cont, Color color) {
    return Text(cont,
      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500));
  }

  // ── Bottom navigation (mobile) ─────────────────────────────────────────────

  /// BottomAppBar com recorte circular (CircularNotchedRectangle) para acomodar
  /// o FAB centralizado sem precisar de posicionamento manual.
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
            // Espaço reservado para o FAB não sobrepor itens de navegação.
            const SizedBox(width: 48),
            _buildNavItem(Icons.bar_chart_outlined, 'Statistics', false),
          ],
        ),
      ),
    );
  }

  /// Item de navegação do BottomAppBar: ícone + rótulo com cor de destaque.
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

  // ── FAB (mobile) ───────────────────────────────────────────────────────────

  /// FloatingActionButton centralizado — encaixado no recorte do BottomAppBar.
  /// CircleBorder garante shape circular independente do tema global do app.
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: const Color(0xFF2C2C54),
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    );
  }
}