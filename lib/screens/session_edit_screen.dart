import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/DAO/question_state_dao.dart';
import '../data/DAO/session_dao.dart';
import '../data/DAO/tag_dao.dart';
import '../data/DTO/session_dto.dart';
import '../styles/app_theme.dart';

class _TagQuota {
  int? tagId;
  int quantity;
  _TagQuota({this.tagId, this.quantity = 1});
}

class SessionEditScreen extends StatefulWidget {
  final Map<String, dynamic>? session;

  const SessionEditScreen({super.key, this.session});

  @override
  State<SessionEditScreen> createState() => _SessionEditScreenState();
}

class _SessionEditScreenState extends State<SessionEditScreen> {
  final _nameController = TextEditingController();
  final _timeController = TextEditingController(text: '30');
  String _timeUnit = 'min';   
  final _totalController = TextEditingController(); 

  List<Map<String, dynamic>> _tags = [];
  Map<int, int> _tagCounts = {}; 
  final List<_TagQuota> _quotas = [];
  final _tagInputController = TextEditingController();
  String _tagQuery = '';
  final _tagFocus = FocusNode();
  _TagQuota? _editingQuota; // tag que está sendo editada (saiu da lista temporariamente)
  static final _quotaPattern = RegExp(r'^#?([^\s=#]+)=(\d+)$');

  bool get _isEditing => widget.session != null;

  bool _unlimitedTime = true;
  bool _loading = true;
  bool _saving = false;
  bool _createdAny = false; 

  @override
  void initState() {
    super.initState();
    _tagFocus.addListener(_onTagFocusChanged);
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await TagDao().getAll();
    final counts = await QuestionDao().getTagCounts();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _tagCounts = counts;
      if (widget.session != null) _applySession(widget.session!);
      _loading = false;
    });
  }

  void _applySession(Map<String, dynamic> s) {
    _nameController.text = (s['title'] as String?) ?? '';

    final seconds = SessionDao.parseTimeLimitSeconds(s['time_limit'] as String?);
    _unlimitedTime = seconds == null;
    if (seconds != null) {
      if (seconds % 3600 == 0) {
        _timeUnit = 'h';
        _timeController.text = (seconds ~/ 3600).toString();
      } else if (seconds % 60 == 0) {
        _timeUnit = 'min';
        _timeController.text = (seconds ~/ 60).toString();
      } else {
        _timeUnit = 's';
        _timeController.text = seconds.toString();
      }
    }

    final total = (s['total_q'] as num?)?.toInt();
    _totalController.text = total == null ? '' : total.toString();

    final filters = SessionDao.parseTagFilters(s['tag_filters'] as String?);
    _quotas
      ..clear()
      ..addAll([
        for (final f in filters)
          if (_tags.any((t) => t['id'] == f['tag_id']))
            _TagQuota(tagId: f['tag_id'], quantity: f['quantity']!),
      ]);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    _totalController.dispose();
    _tagFocus.removeListener(_onTagFocusChanged);
    _tagFocus.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  static const Map<String, int> _unitSeconds = {'s': 1, 'min': 60, 'h': 3600};

  int? get _limitSeconds {
    final n = int.tryParse(_timeController.text.trim());
    if (n == null || n < 1) return null;
    return n * (_unitSeconds[_timeUnit] ?? 60);
  }

  int? get _total {
    final n = int.tryParse(_totalController.text.trim());
    return (n == null || n < 1) ? null : n;
  }

  int get _quotaSum => _quotas.fold(0, (sum, q) => sum + q.quantity);

  int? get _remaining => _total == null ? null : _total! - _quotaSum;

  void _showError(String message) => _showMessage(message);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _resetForm() {
    _nameController.clear();
    _timeController.text = '30';
    _timeUnit = 'min';
    _totalController.clear();
    _unlimitedTime = true;
    _quotas.clear();
    _tagInputController.clear();
    _tagQuery = '';
    _editingQuota = null;
  }

  String _tagTitle(int? id) => _tags.firstWhere(
        (t) => t['id'] == id,
        orElse: () => {'title': '?'},
      )['title'] as String;

  void _quickWarning(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
  }

  static String _clean(String s) =>
      s.trim().replaceAll(RegExp(r',+$'), '').trim();

  void _onTagInputChanged(String text) {
    // espaço ou vírgula no final = fecha o token "tag=num" e vira tag
    final closed = text.endsWith(' ') || text.endsWith(',');
    if (closed && _quotaPattern.hasMatch(_clean(text))) {
      _commitTagInput();
      return;
    }
    final token = text.split(RegExp(r'[\s,]+')).last;
    setState(() => _tagQuery = token.contains('=') ? '' : token);
  }

  void _selectSuggestedTag(String title) {
    _tagInputController.value = TextEditingValue(
      text: '$title=',
      selection: TextSelection.collapsed(offset: title.length + 1),
    );
    setState(() => _tagQuery = '');
    _tagFocus.requestFocus();
  }

  /// Transforma o texto do campo em tag. Retorna false se não conseguiu.
  bool _commitTagInput({bool warnFormat = true}) {
    final raw = _clean(_tagInputController.text);
    if (raw.isEmpty) return true;

    final m = _quotaPattern.firstMatch(raw);
    if (m == null) {
      if (warnFormat) {
        _quickWarning('Use o formato tag=quantidade, ex.: matematica=4');
      }
      return false;
    }

    final name = m.group(1)!;
    final qty = int.parse(m.group(2)!);
    final tag = _tags
        .where((t) => (t['title'] as String).toLowerCase() == name.toLowerCase())
        .firstOrNull;

    if (tag == null) {
      _quickWarning('A tag "$name" não existe.');
      return false;
    }
    if (qty < 1) {
      _quickWarning('Cada tag precisa de pelo menos 1 questão.');
      return false;
    }

    final id = tag['id'] as int;
    final others = _quotas
        .where((q) => q.tagId != id)
        .fold<int>(0, (s, q) => s + q.quantity);

    if (_total != null && others + qty > _total!) {
      _quickWarning(
        'A soma não pode passar do total da sessão ($_total).',
      );
      return false;
    }

    setState(() {
      _quotas.removeWhere((q) => q.tagId == id);
      _quotas.add(_TagQuota(tagId: id, quantity: qty));
      _tagInputController.clear();
      _tagQuery = '';
      _editingQuota = null;
    });
    return true;
  }

  void _editQuota(_TagQuota q) {
    if (_tagInputController.text.trim().isNotEmpty && !_commitTagInput()) return;
    final text = '${_tagTitle(q.tagId)}=${q.quantity}';
    setState(() {
      _quotas.remove(q);
      _editingQuota = q;
      _tagInputController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _tagQuery = '';
    });
    _tagFocus.requestFocus();
  }

  void _onTagFocusChanged() {
    if (!mounted) return;
    if (_tagFocus.hasFocus) {
      setState(() {});
      return;
    }
    if (_commitTagInput(warnFormat: false)) {
      setState(() {});
      return;
    }
    final editing = _editingQuota;
    setState(() {
      if (editing != null) {
        _quotas.add(editing);
        _editingQuota = null;
        _tagInputController.clear();
        _tagQuery = '';
      }
    });
  }

  Future<void> _save() async {
    if (_tagInputController.text.trim().isNotEmpty && !_commitTagInput()) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Dê um nome à sessão.');
      return;
    }

    final totalText = _totalController.text.trim();
    if (totalText.isNotEmpty && (int.tryParse(totalText) ?? 0) < 1) {
      _showError('A quantidade de questões deve ser maior que zero (ou deixe vazio para ilimitado).');
      return;
    }
    final int? total = _total;

    int? limitSeconds;
    if (!_unlimitedTime) {
      limitSeconds = _limitSeconds;
      if (limitSeconds == null) {
        _showError('Defina o tempo limite (um número maior que zero).');
        return;
      }
    }

    List<Map<String, int>>? filters;
    if (_quotas.isNotEmpty) {
      if (_quotas.any((q) => q.tagId == null || q.quantity < 1)) {
        _showError('Cada tag precisa de pelo menos 1 questão.');
        return;
      }
      if (total != null && _quotaSum > total) {
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
      final dto = SessionDto(
        id: widget.session?['id'] as int?,
        title: name,
        time_limit: SessionDao.formatTimeLimit(limitSeconds), 
        total_q: total,
        tagFilters: filters == null ? null : jsonEncode(filters),
      );
      if (_isEditing) {
        await SessionDao().update(dto);
        if (mounted) Navigator.pop(context, true);
      } else {
        await SessionDao().insert(dto);
        _createdAny = true;
        if (!mounted) return;
        setState(() {
          _resetForm();
          _saving = false;
        });
        _showMessage('Sessão "$name" salva.');
      }
    } catch (e) {
      debugPrint('Erro ao salvar sessão: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      _showError('Não foi possível salvar a sessão: $e');
    }
  }

  void _leave() {
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.pop(context, _createdAny);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.text),
          onPressed: () => _leave(),
        ),
        title: Text(_isEditing ? 'Editar sessão' : 'Nova sessão',
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

                const SizedBox(height: 16),
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
                  _buildTimeLimitInput(),
                ],
                const SizedBox(height: 16),
                _numberField(
                  _totalController,
                  'Total de questões',
                  hint: 'Ilimitado',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                _buildTagFilter(),
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

  Widget _buildTimeLimitInput() {
    final c = context.colors;
    final seconds = _limitSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _numberField(
                _timeController,
                'Tempo limite',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: _timeUnit,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 's', child: Text('Segundos')),
                  DropdownMenuItem(value: 'min', child: Text('Minutos')),
                  DropdownMenuItem(value: 'h', child: Text('Horas')),
                ],
                onChanged: (v) => setState(() => _timeUnit = v ?? 'min'),
                decoration: InputDecoration(
                  labelText: 'Unidade',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        if (seconds != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Cronômetro: ${SessionDao.describeTimeLimit(seconds)}',
              style: TextStyle(fontSize: 12, color: c.mutedText),
            ),
          ),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: hint != null ? FloatingLabelBehavior.always : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildTagFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tags.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nenhuma tag cadastrada ainda. Crie uma pelo botão + (Nova tag).',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          )
        else ...[
          _buildTagInput(),
          const SizedBox(height: 6),
          _buildRemainingInfo(),
        ],
      ],
    );
  }

  Widget _buildTagInput() {
    final query = _tagQuery.toLowerCase();
    final matches = query.isEmpty
        ? const <Map<String, dynamic>>[]
        : _tags
            .where((t) => (t['title'] as String).toLowerCase().contains(query))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _tagFocus.requestFocus(),
          child: InputDecorator(
            isFocused: _tagFocus.hasFocus,
            isEmpty: _quotas.isEmpty && _tagInputController.text.isEmpty,
            decoration: InputDecoration(
              labelText: 'Tags',
              hintText: 'Ex: tag=2',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final q in _quotas) _buildQuotaChip(q),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _tagInputController,
                    focusNode: _tagFocus,
                    onChanged: _onTagInputChanged,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      _commitTagInput();
                      _tagFocus.requestFocus();
                    },
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in matches)
                ActionChip(
                  label: Text('#${t['title']} · ${_tagCounts[t['id']] ?? 0}'),
                  backgroundColor: context.colors.accent.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  onPressed: () => _selectSuggestedTag(t['title'] as String),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQuotaChip(_TagQuota q) {
    final c = context.colors;
    return GestureDetector(
      onDoubleTap: () => _editQuota(q),
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_tagTitle(q.tagId)} ${q.quantity}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(width: 2),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _quotas.remove(q)),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: c.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemainingInfo() {
    final remaining = _remaining;
    if (remaining == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'Distribuídas $_quotaSum · total ilimitado',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.mutedText,
          ),
        ),
      );
    }
    final over = remaining < 0;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        over
            ? 'A soma das tags ($_quotaSum) passa do total da sessão ($_total).'
            : 'Distribuídas $_quotaSum de $_total',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: over ? const Color(0xFFC62828) : context.colors.mutedText,
        ),
      ),
    );
  }
}