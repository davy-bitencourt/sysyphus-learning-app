import 'package:flutter/material.dart';
import '../widgets/heatmap_card.dart';


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

  /// Breakpoint simples: ≥ 600px de largura é tratado como desktop/tablet.
  /// Evita importar pacotes externos de responsividade para algo tão direto.
  static bool _isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= 600;

  //Build principal
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    print(" W:${size.width} | H:${size.height}");  // largura

    final desktop = _isDesktop(context);
    return Scaffold(
      // Cor de fundo neutra que contrasta com os cards brancos.
      backgroundColor: const Color(0xFFFFFFFF),
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
          HeatmapCard(activityMap: _buildActivityMap()),          
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
  // ── Desktop ────────────────────────────────────────────────────────────────
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
          // define largura de cada coluna
          columnWidths: const {
            0: FlexColumnWidth(),   // título — ocupa o resto
            1: FixedColumnWidth(100), // Novo
            2: FixedColumnWidth(100), // Reforço
            3: FixedColumnWidth(40), // engrenagem
          },
          children: [

            // cabeçalho
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

            // linhas dos decks
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
  // ── Widgets pequenos ───────────────────────────────────────────────────────
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
          color: isActive ? const Color(0xFFFF8F00) : Colors.grey[400], size: 24),
        Text(label,
          style: TextStyle(fontSize: 11,
            color: isActive ? const Color(0xFFFF8F00) : Colors.grey[400])),
      ],
    );
  }

  // ── FAB (mobile) ───────────────────────────────────────────────────────────
  /// FloatingActionButton centralizado — encaixado no recorte do BottomAppBar.
  /// CircleBorder garante shape circular independente do tema global do app.
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: const Color(0xFFE65100),
      shape: const CircleBorder(),
      child: const Icon(Icons.add, color: Colors.white, size: 28),
    );
  }
}