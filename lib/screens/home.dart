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

  // ── Build principal ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
      leadingWidth: 160,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(children: [
          // Logo: Container com ícone — substitui uma imagem real sem asset extra.
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
        // Links de nav só no desktop — no mobile a BottomNav cumpre esse papel.
        IconButton(icon: const Icon(Icons.sync, color: Color(0xFF555555)), onPressed: () {}),
        IconButton(icon: const Icon(Icons.menu, color: Color(0xFF555555)), onPressed: () {}),
      ],
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
          _buildSearchBar(),
          const SizedBox(height: 20),
          _sectionLabel('My Latest Review'),
          const SizedBox(height: 10),
          _buildHeatmapCard(),
          const SizedBox(height: 20),
          _buildTabBar(),
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

  /// Layout desktop: sidebar fixa à esquerda + área de conteúdo à direita.
  /// Row de nível superior; a sidebar tem altura infinita para preencher a tela.
  Widget _buildDesktopBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Sidebar ──────────────────────────────────────────────────────────
        // Container com cor sólida faz a barra lateral. width fixo de 220px é
        // suficiente para labels curtos sem desperdiçar espaço.
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
              _sidebarItem(Icons.home_outlined,     'Home',       true),
              _sidebarItem(Icons.bar_chart_outlined, 'Statistics', false),
              _sidebarItem(Icons.settings_outlined,  'Settings',   false),
              // Spacer empurra o botão "Nova Deck" para o fundo da sidebar.
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nova Deck'),
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

        // ── Conteúdo principal ────────────────────────────────────────────────
        // Expanded faz o conteúdo ocupar todo o espaço restante após a sidebar.
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

                // ── FIX: Column em vez de GridView ────────────────────────────
                //
                // O GridView anterior usava childAspectRatio: 3.8, que impunha
                // uma altura fixa a cada célula (~altura/3.8). O conteúdo dos
                // cards (thumbnail 64px + texto + tags + padding) excedia essa
                // altura calculada, causando RenderFlex overflows tanto no eixo
                // vertical (bottom) quanto horizontal (right).
                //
                // A correção mais simples e robusta é substituir o GridView por
                // uma Column: cada card define sua própria altura com base no
                // conteúdo, eliminando qualquer overflow por altura insuficiente.
                //
                // Alternativa com 2 colunas: usar Wrap (veja comentário abaixo).
                Column(
                  children: _decks.map(_buildDeckCard).toList(),
                ),

                // ── Alternativa: 2 colunas sem altura fixa com Wrap ───────────
                //
                // Se quiser manter o grid de 2 colunas, use Wrap dentro de um
                // LayoutBuilder para calcular a largura disponível:
                //
                // LayoutBuilder(builder: (context, constraints) {
                //   return Wrap(
                //     spacing: 12,
                //     runSpacing: 12,
                //     children: _decks.map((deck) => SizedBox(
                //       // Metade da largura disponível menos o espaço entre colunas
                //       width: (constraints.maxWidth - 12) / 2,
                //       child: _buildDeckCard(deck),
                //     )).toList(),
                //   );
                // }),
                //
                // Wrap não impõe altura: cada "linha" se expande para caber o
                // card mais alto, resolvendo o overflow sem precisar de aspectRatio.
              ],
            ),
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

  /// Barra de busca estilizada como campo flutuante.
  /// Container com BoxShadow imita elevação sem usar Material/Card,
  /// permitindo controle total do radius e cor.
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
          // InputBorder.none remove a linha padrão do TextField; o visual
          // vem inteiramente do Container externo.
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

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
    // Dimensões dos quadradinhos do heatmap.
    const double cellSize  = 11;
    const double cellGap   = 2;
    // Passo de cada coluna: tamanho + gap entre células.
    const double cellStep  = cellSize + cellGap; // 13 px por slot de coluna
    // Largura reservada para os rótulos dos dias (Mon/Wed/Fri).
    const double dayLabelW = 26;
    // Gap entre os rótulos e a grade de células.
    const double labelGap  = 4;

    final today       = DateTime.now();
    final todayNorm   = DateTime(today.year, today.month, today.day);
    final activityMap = _buildActivityMap();
    final monthNames  = ['Jan','Feb','Mar','Apr','May','Jun',
                         'Jul','Aug','Sep','Oct','Nov','Dec'];

    // Segunda-feira da semana atual — ponto de ancoragem do grid.
    final thisMonday = todayNorm.subtract(Duration(days: todayNorm.weekday - 1));

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
      // LayoutBuilder fornece a largura real disponível após o padding do
      // Container pai ser consumido pelo Flutter — não precisa subtrair manualmente.
      child: LayoutBuilder(builder: (context, constraints) {
        final double availW   = constraints.maxWidth - dayLabelW - labelGap;
        // ~/ trunca para baixo: garante que nunca haverá mais colunas do que cabem.
        final int visibleCols = availW ~/ cellStep;

        // Centraliza "hoje" horizontalmente: metade das colunas antes, metade depois.
        final int colsBefore       = visibleCols ~/ 2;
        final DateTime firstMonday = thisMonday.subtract(Duration(days: colsBefore * 7));

        // Largura exata da grade: remove o gap que sobra após a última coluna.
        final double gridW = visibleCols * cellStep - cellGap;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Cabeçalho: título + streak badge
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
                // Badge de streak: Container arredondado com fundo translúcido verde.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: const Text('🔥 12 day streak',
                    style: TextStyle(fontSize: 11, color: Color(0xFF216E39),
                      fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grade de dias: rótulos à esquerda + colunas de células à direita.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coluna de rótulos dos dias da semana (alinhados à direita).
                SizedBox(
                  width: dayLabelW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Espaçador para alinhar verticalmente com os rótulos de mês.
                      const SizedBox(height: 14),
                      ...List.generate(7, (i) {
                        // Exibe apenas Mon, Wed, Fri para não poluir o layout.
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

                // Área da grade com largura exata calculada para evitar overflow.
                SizedBox(
                  width: gridW,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Rótulos de mês: Stack posicionado absolutamente por coluna.
                      // height 14 reserva espaço fixo acima das células.
                      SizedBox(
                        height: 14,
                        child: Stack(
                          children: List.generate(visibleCols, (ci) {
                            final monday = firstMonday.add(Duration(days: ci * 7));
                            String? label;
                            // Verifica se algum dia da semana é dia 1 → novo mês.
                            for (int d = 0; d < 7; d++) {
                              final day = monday.add(Duration(days: d));
                              if (day.day == 1) {
                                label = monthNames[day.month - 1];
                                break;
                              }
                            }
                            if (label == null) return const SizedBox.shrink();
                            return Positioned(
                              left: ci * cellStep.toDouble(),
                              child: Text(label,
                                style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                            );
                          }),
                        ),
                      ),

                      // Grade de células: Row de colunas semanais.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(visibleCols, (ci) {
                          final monday = firstMonday.add(Duration(days: ci * 7));
                          // SizedBox com largura fixa garante espaçamento uniforme
                          // sem depender de Flexible ou Expanded (evita overflow).
                          return SizedBox(
                            width: cellStep,
                            child: Column(
                              children: List.generate(7, (d) {
                                final date    = monday.add(Duration(days: d));
                                final dateKey = DateTime(date.year, date.month, date.day);
                                final isToday  = dateKey == todayNorm;
                                final isFuture = date.isAfter(todayNorm);
                                // Dias futuros sempre exibem cor neutra (sem atividade).
                                final value = isFuture ? 0 : (activityMap[dateKey] ?? 0);
                                return Container(
                                  width: cellSize, height: cellSize,
                                  margin: const EdgeInsets.only(bottom: cellGap),
                                  decoration: BoxDecoration(
                                    color: isFuture
                                        ? const Color(0xFFF0F0F0)
                                        : _heatColor(value),
                                    borderRadius: BorderRadius.circular(2),
                                    // Borda azul destaca "hoje" na grade.
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

            // Rodapé: legenda de intensidade + chips de estatísticas.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Legenda "Less → More" com amostras de cor.
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
                // Chips de contagem por tipo de cartão.
                Row(children: [
                  _buildStatChip('60', 'Nova',    const Color(0xFF1565C0)),
                  const SizedBox(width: 6),
                  _buildStatChip('10', 'Reforço', const Color(0xFFC62828)),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            
          ],
        );
      }),
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
        // Placeholder de thumbnail — substituir por Image.network/asset em produção.
        Container(width: 64, height: 64,
          decoration: BoxDecoration(
            color: Colors.grey[200], borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 12),
        // Expanded garante que o texto não transborde horizontalmente.
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
            // Wrap permite que as tags quebrem para a próxima linha se não
            // couberem na largura disponível — mais robusto que Row fixo.
            Wrap(spacing: 6, runSpacing: 4, children: [
              _buildTag('60 Nova'),
              _buildTag('10 Reforço'),
            ]),
          ]),
        ),
        // Ícone de expansão — sinalizador visual de que o card é interativo.
        Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 24),
      ]),
    );
  }

  // ── Widgets pequenos ───────────────────────────────────────────────────────

  /// Chip colorido para estatísticas (Nova / Learn / Review).
  /// Fundo com opacidade reduzida evita vibração de cor; texto usa a cor plena.
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

  /// Tag de categoria dos cards dentro do deck.
  /// Fundo cinza neutro para não disputar atenção com as estatísticas coloridas.
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

  // ── Tab bar ────────────────────────────────────────────────────────────────

  /// Tab bar customizada com indicador de sublinhado animado por setState.
  /// Usa GestureDetector em vez de TabBar do Material para evitar dependência
  /// de TabController e manter o código auto-contido.
  Widget _buildTabBar() {
    return Row(children: [
      _buildTab('My Decks', 0),
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
          // Indicador: Container fino só aparece na aba ativa.
          // Largura proporcional ao texto usando fator empírico (7.5px/char).
          if (sel)
            Container(height: 2, width: title.length * 7.5,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
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