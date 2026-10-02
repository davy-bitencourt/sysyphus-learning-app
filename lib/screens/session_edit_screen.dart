import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/DAO/question_state_dao.dart';
import '../data/DAO/tag_dao.dart';
import '../data/database_helper.dart';
import '../styles/app_theme.dart';

/// Quanto de uma tag entra na sessão (ex.: 10 questões de #matemática).
class _TagQuota {
  int? tagId;
  int quantity;
  _TagQuota({this.tagId, this.quantity = 1});
}

/// Criação de uma sessão de estudo:
///  - nome;
///  - tempo limite em minutos, ou sem limite (infinito);
///  - total de questões que poderão ser feitas na sessão;
///  - filtro opcional por tag: quantas questões vêm de cada tag. A soma das
///    quantidades por tag não pode passar do total da sessão.
class SessionEditScreen extends StatefulWidget {
  const SessionEditScreen({super.key});

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  final _nameController = TextEditingController();
  final _minutesController = TextEditingController(text: '30');
  final _totalController = TextEditingController(text: '20');

  List<Map<String, dynamic>> _tags = [];
  Map<int, int> _tagCounts = {}; // tag_id -> questões que existem naquela tag
  final List<_TagQuota> _quotas = [];

  bool _unlimitedTime = true;
  bool _filterByTag = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await TagDao().getAll();
    final counts = await QuestionDao().getTagCounts();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _tagCounts = counts;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minutesController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  int get _total => int.tryParse(_totalController.text.trim()) ?? 0;
  int get _quotaSum => _quotas.fold(0, (sum, q) => sum + q.quantity);
  int get _remaining => _total - _quotaSum;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onFilterToggled(bool value) {
    setState(() {
      _filterByTag = value;
      if (value && _quotas.isEmpty && _tags.isNotEmpty) _addQuota();
    });
  }

  void _addQuota() {
    final used = _quotas.map((q) => q.tagId).toSet();
    final free = _tags.where((t) => !used.contains(t['id'] as int)).toList();
    if (free.isEmpty) {
      _showError('Todas as tags já foram adicionadas.');
      return;
    }
    setState(() {
      _quotas.add(_TagQuota(
        tagId: free.first['id'] as int,
        quantity: _remaining > 0 ? 1 : 0,
      ));
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Dê um nome à sessão.');
      return;
    }

    final total = _total;
    if (total < 1) {
      _showError('Defina quantas questões a sessão terá.');
      return;
    }

    int? minutes;
    if (!_unlimitedTime) {
      minutes = int.tryParse(_minutesController.text.trim());
      if (minutes == null || minutes < 1) {
        _showError('Defina o tempo limite em minutos.');
        return;
      }
    }

    List<Map<String, int>>? filters;
    if (_filterByTag) {
      if (_quotas.isEmpty) {
        _showError('Escolha ao menos uma tag ou desligue o filtro por tag.');
        return;
      }
      if (_quotas.any((q) => q.tagId == null || q.quantity < 1)) {
        _showError('Cada tag precisa de pelo menos 1 questão.');
        return;
      }
      if (_quotaSum > total) {
        _showError(
          'A soma das questões por tag ($_quotaSum) não pode passar do '
          'total da sessão ($total).',
        );
        return;
      }
      filters = [
        for (final q in _quotas) {'tag_id': q.tagId!, 'quantity': q.quantity},
      ];
    }

    setState(() => _saving = true);
    try {
      final db = await DatabaseHelper.instance.database;
      // time_limit: minutos (texto) ou NULL = sem limite.
      await db.rawInsert(
        'INSERT INTO session (title, time_limit, total_q, tag_filters) '
        'VALUES (?, ?, ?, ?)',
        [name, minutes?.toString(), total, filters == null ? null : jsonEncode(filters)],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Erro ao salvar sessão: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Não foi possível salvar a sessão: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Nova sessão',
          style: TextStyle(color: context.colors.text,
            fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nome da sessão',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 28),

                _sectionTitle('Tempo limite'),
                const SizedBox(height: 4),
                Text(
                  'Sem limite: a sessão só termina quando você acabar as questões.',
                  style: TextStyle(fontSize: 12, color: context.colors.mutedText),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Sem limite'),
                        icon: Icon(Icons.all_inclusive),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Limitar'),
                        icon: Icon(Icons.timer_outlined),
                      ),
                    ],
                    selected: {_unlimitedTime},
                    onSelectionChanged: (selection) =>
                        setState(() => _unlimitedTime = selection.first),
                  ),
                ),
                if (!_unlimitedTime) ...[
                  const SizedBox(height: 12),
                  _numberField(_minutesController, 'Tempo limite (minutos)'),
                ],
                const SizedBox(height: 28),

                _sectionTitle('Quantidade de questões'),
                const SizedBox(height: 4),
                Text(
                  'Quantas questões poderão ser feitas nesta sessão de estudo.',
                  style: TextStyle(fontSize: 12, color: context.colors.mutedText),
                ),
                const SizedBox(height: 10),
                _numberField(
                  _totalController,
                  'Total de questões',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 28),

                _buildTagFilter(),
                const SizedBox(height: 16),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: context.colors.bg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_saving || _loading) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_saving ? 'Salvando...' : 'Salvar sessão',
                style: const TextStyle(fontSize: 15)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.text));
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildTagFilter() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Filtrar por tag')),
            Switch(value: _filterByTag, onChanged: _onFilterToggled),
          ],
        ),
        Text(
          _filterByTag
              ? 'Escolha quantas questões vêm de cada tag. A soma não pode '
                'passar do total da sessão.'
              : 'Sem filtro: a sessão usa questões de qualquer tag.',
          style: TextStyle(fontSize: 12, color: c.mutedText),
        ),
        if (_filterByTag) ...[
          const SizedBox(height: 12),
          if (_tags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma tag cadastrada ainda. Crie uma pelo botão + (Nova tag).',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            )
          else ...[
            for (int i = 0; i < _quotas.length; i++) _buildQuotaRow(_quotas[i], i),
            _buildRemainingInfo(),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addQuota,
                icon: Icon(Icons.add, size: context.icon(20), color: c.accent),
                label: Text('Adicionar tag', style: TextStyle(color: c.accent)),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildQuotaRow(_TagQuota quota, int index) {
    final c = context.colors;
    // Cada tag só pode aparecer uma vez: esta linha enxerga a própria tag e
    // as que ainda não foram usadas por outra linha.
    final options = _tags.where((t) {
      final id = t['id'] as int;
      return id == quota.tagId || !_quotas.any((o) => o.tagId == id);
    }).toList();
    final inTag = quota.tagId == null ? null : _tagCounts[quota.tagId];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: quota.tagId,
                  isExpanded: true,
                  items: options
                      .map((t) => DropdownMenuItem(
                            value: t['id'] as int,
                            child: Text('#${t['title']}'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => quota.tagId = v),
                  decoration: InputDecoration(
                    labelText: 'Tag',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _quotas.removeAt(index)),
                icon: Icon(Icons.close, size: context.icon(18), color: Colors.grey[500]),
              ),
            ],
          ),
          Row(
            children: [
              Text('Questões:', style: TextStyle(fontSize: 13, color: c.text)),
              IconButton(
                onPressed: quota.quantity > 1 ? () => setState(() => quota.quantity--) : null,
                icon: Icon(Icons.remove_circle_outline, size: context.icon(22)),
              ),
              Text('${quota.quantity}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text)),
              IconButton(
                onPressed: _remaining > 0 ? () => setState(() => quota.quantity++) : null,
                icon: Icon(Icons.add_circle_outline, size: context.icon(22)),
              ),
              const Spacer(),
              if (inTag != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('$inTag com esta tag',
                    style: TextStyle(fontSize: 11, color: c.mutedText)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingInfo() {
    final over = _remaining < 0;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        over
            ? 'A soma das tags ($_quotaSum) passa do total da sessão ($_total).'
            : 'Distribuídas $_quotaSum de $_total · restam $_remaining',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: over ? const Color(0xFFC62828) : context.colors.mutedText,
        ),
      ),
    );
  }
}
