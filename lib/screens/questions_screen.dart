import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import '../data/schema/question_schema.dart';
import '../data/schema/template_schema.dart';
import '../data/DAO/question_state_dao.dart';
import '../data/DAO/revlog_dao.dart';
import '../data/DAO/session_dao.dart';
import '../data/models/field_model.dart';
import '../data/models/question_model.dart';
import 'questions_edit_screen.dart';
import '../widgets/markdown_text.dart';

class QuestionScreen extends StatefulWidget {
  final int packageId;
  final int limit;

  const QuestionScreen({
    super.key,
    required this.packageId,
    this.limit = 20,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  final QuestionSchema _questionSchema = QuestionSchema();
  final TemplateSchema _templateSchema = TemplateSchema();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<LoadedQuestion> _questions = [];
  bool _loading = true;

  int _currentQuestion = 0;
  bool _answered = false;
  String? _playingFieldId;

  Timer? _timer;
  DateTime? _endsAt;
  bool _timerStarted = false;
  bool _timeUpPending = false; 
  int _answeredCount = 0;
  final ValueNotifier<Duration?> _timeLeft = ValueNotifier<Duration?>(null);

  final Map<String, int?> _selectedOptionByField = {};
  final Map<String, Map<int, bool>> _vofAnswersByField = {};

  final Map<String, List<OptionValue>> _shuffledOptionsCache = {};

  LoadedQuestion get _current => _questions[_currentQuestion];

  List<OptionValue> _optionsFor(FieldDefinition field) {
    final base = _current.question.optionsFor(field.id);
    if (field.type != FieldType.options) return base;

    final key = '$_currentQuestion:${field.id}';
    return _shuffledOptionsCache.putIfAbsent(key, () {
      final shuffled = List<OptionValue>.from(base);
      shuffled.shuffle();
      return shuffled;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timeLeft.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);

    final session = await SessionDao().getByPackage(widget.packageId);
    final totalQ = (session?['total_q'] as num?)?.toInt();
    final limitSeconds = SessionDao.parseTimeLimitSeconds(session?['time_limit'] as String?);

    final List<Map<String, dynamic>> rows;
    if (session != null && totalQ != null && totalQ > 0) {
      rows = await QuestionDao().getForSession(
        widget.packageId,
        totalQ,
        SessionDao.parseTagFilters(session['tag_filters'] as String?),
      );
    } else {
      await _questionSchema.getQuestionData(widget.packageId, widget.limit);
      rows = _questionSchema.question_schema;
    }

    final loaded = <LoadedQuestion>[];
    for (final row in rows) {
      final templateId = row['template_id'] as int?;
      if (templateId == null) continue;

      await _templateSchema.isOnCache(templateId);
      final templateMap = _templateSchema.template_schema[templateId];
      if (templateMap == null) continue;

      final template = TemplateModel.fromMap(templateId, templateMap);
      final question = Question.fromDb(row);
      loaded.add(LoadedQuestion(question: question, template: template));
    }

    if (!mounted) return;
    setState(() {
      _questions = loaded;
      _currentQuestion = 0;
      _shuffledOptionsCache.clear();
      _resetAnswerState();
      _loading = false;
    });

    if (loaded.isNotEmpty && limitSeconds != null) _startTimer(limitSeconds);
  }

  void _startTimer(int seconds) {
    if (_timerStarted) return;
    setState(() => _timerStarted = true);
    _endsAt = DateTime.now().add(Duration(seconds: seconds));
    _timeLeft.value = Duration(seconds: seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final endsAt = _endsAt;
    if (endsAt == null || !mounted) return;

    final left = endsAt.difference(DateTime.now());
    if (left <= Duration.zero) {
      _timer?.cancel();
      _timer = null;
      _timeLeft.value = Duration.zero;
      _onTimeUp();
    } else {
      _timeLeft.value = left;
    }
  }

  Future<void> _onTimeUp() async {
    await _audioPlayer.stop();
    if (!mounted) return;

    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      _timeUpPending = true;
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tempo esgotado'),
        content: Text(
          'O tempo limite da sessão acabou. Você respondeu '
          '$_answeredCount de ${_questions.length} questões.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final sec = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  Widget _buildTimerLabel() {
    return ValueListenableBuilder<Duration?>(
      valueListenable: _timeLeft,
      builder: (context, left, _) {
        final d = left ?? Duration.zero;
        final urgent = d.inSeconds <= 60; // último minuto em vermelho
        final color = urgent ? const Color(0xFFC62828) : context.colors.mutedText;
        return SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: context.icon(16), color: color),
              const SizedBox(width: 4),
              Text(
                _formatDuration(d),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resetAnswerState() {
    _answered = false;
    _selectedOptionByField.clear();
    _vofAnswersByField.clear();
    _playingFieldId = null;
  }

  bool _hasGradableField(LoadedQuestion q) =>
      q.template.fields.any((f) => f.type == FieldType.options || f.type == FieldType.vof);

  bool _isMultiSelect(LoadedQuestion q, FieldDefinition field) {
    if (field.type == FieldType.vof) return true;
    if (field.type != FieldType.options) return false;
    return q.question.optionsFor(field.id).where((o) => o.correct).length > 1;
  }

  bool _isCurrentAnswerCorrect(LoadedQuestion q) {
    bool anyGraded = false;
    for (final field in q.template.fields) {
      if (field.type != FieldType.options && field.type != FieldType.vof) continue;

      anyGraded = true;
      final options = _optionsFor(field);

      if (_isMultiSelect(q, field)) {
        final answers = _vofAnswersByField[field.id] ?? {};
        for (int i = 0; i < options.length; i++) {
          final marked = answers[i] == true;
          if (marked != options[i].correct) return false;
        }
      } else {
        final selected = _selectedOptionByField[field.id];
        if (selected == null || selected >= options.length || !options[selected].correct) {
          return false;
        }
      }
    }
    return anyGraded;
  }

  double? _answerScore(LoadedQuestion q) {
    double sum = 0;
    int fields = 0;
    for (final field in q.template.fields) {
      if (field.type != FieldType.options && field.type != FieldType.vof) continue;

      fields++;
      final options = _optionsFor(field);

      if (_isMultiSelect(q, field)) {
        final answers = _vofAnswersByField[field.id] ?? {};
        int rightMarked = 0;
        int totalCorrect = 0;
        for (int i = 0; i < options.length; i++) {
          final marked = answers[i] == true;
          if (options[i].correct) {
            totalCorrect++;
            if (marked) rightMarked++;
          }
        }
          sum += (rightMarked / totalCorrect).clamp(0.0, 1.0).toDouble();
      } else {
        final selected = _selectedOptionByField[field.id];
        if (selected != null && selected < options.length && options[selected].correct) {
          sum += 1.0;
        }
      }
    }
    return fields == 0 ? null : sum / fields;
  }

  void _showAnswer() => setState(() => _answered = true);

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _registerAndNext(bool correct) async {
    final question = _current.question;
    final dao = QuestionDao();
    final revlogDao = RevlogDao();
    final now = DateTime.now();
    final today = _formatDate(now);

    if (question.id != null) {
      await revlogDao.insert(question.id!, today, now.toIso8601String());

      if (correct) {
        final prevInterval = question.intervalDays ?? 0;
        final prevEase = question.easeFactor ?? 2.4;
        final newInterval = prevInterval <= 0 ? 1 : (prevInterval * prevEase).round();
        final newEase = (prevEase + 0.1).clamp(1.3, 3.0);
        final dueDate = _formatDate(now.add(Duration(days: newInterval)));
        await dao.updateStateReview(question.id!, newInterval, newEase, dueDate);
      } else {
        await dao.updateStateNeutral(question.id!);
      }
    }

    _answeredCount++;
    _next();
  }

  void _next() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _resetAnswerState();
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _toggleAudio(String fieldId, String path) async {
    if (_playingFieldId == fieldId) {
      await _audioPlayer.stop();
      setState(() => _playingFieldId = null);
      return;
    }
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
    setState(() => _playingFieldId = fieldId);
    _audioPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playingFieldId = null);
    });
  }

  Future<void> _openNewQuestion() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuestionsEditScreen(packageId: widget.packageId)),
    );
    if (_timeUpPending && mounted) {
      _timeUpPending = false;
      await _onTimeUp();
      return;
    }
    if (result == true) _loadQuestions();
  }

  Future<void> _openEditQuestion() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionsEditScreen(
          question: _current.question,
          packageId: widget.packageId,
        ),
      ),
    );
    if (_timeUpPending && mounted) {
      _timeUpPending = false;
      await _onTimeUp();
      return;
    }
    if (result == true) _loadQuestions();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.text),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_outlined, size: context.icon(64), color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Nenhuma questão neste pacote ainda.', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _openNewQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Adicionar questão'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    PopupMenuItem<String> item(String value, IconData icon, String label, {Color? color}) {
      final c = color ?? context.colors.text;
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: context.icon(20), color: c),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: c)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.bg,
      appBar: AppBar(
        backgroundColor: context.colors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_currentQuestion + 1} / ${_questions.length}',
              style: TextStyle(fontSize: 14, color: context.colors.mutedText)),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: LinearProgressIndicator(
                value: (_currentQuestion + 1) / _questions.length,
                backgroundColor: context.colors.border,
                color: context.colors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: _timerStarted
            ? PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: _buildTimerLabel(),
              )
            : null,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opções',
            color: context.colors.surface,
            icon: Icon(Icons.more_vert, size: context.icon(20), color: Colors.grey[500]),
            onSelected: (value) {
              if (value == 'edit') _openEditQuestion();
              if (value == 'add') _openNewQuestion();
            },
            itemBuilder: (_) => [
              item('edit', Icons.edit_outlined, 'Editar'),
              item('add', Icons.add, 'Adicionar'),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _centered(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._current.template.questionFields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: f.isStatement ? _buildStatement() : _buildFieldDisplay(f),
                )),
            if (_answered) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Divider(color: context.colors.border, thickness: 1.5)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _buildAnswerStatusIcon(),
                ),
                Expanded(child: Divider(color: context.colors.border, thickness: 1.5)),
              ]),
              const SizedBox(height: 16),
              _buildScoreLabel(),
              ..._current.template.answerFields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildFieldDisplay(f),
                  )),
              _buildExtraComments(),
            ],
            const SizedBox(height: 100),
          ],
        )),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildStatement() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: MarkdownText(
        text: _current.question.statement,
        style: TextStyle(fontSize: 16, color: context.colors.text),
      ),
    );
  }

  Widget _buildScoreLabel() {
    if (!_hasGradableField(_current)) return const SizedBox.shrink();
  
    final score = _answerScore(_current);
    if (score == null) return const SizedBox.shrink();
  
    final percent = (score * 100).round();
    final color = percent == 100
        ? const Color(0xFF2E7D32)
        : percent == 0
            ? const Color(0xFFC62828)
            : const Color(0xFFEF6C00);
  
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Text(
          '$percent%',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }

  Widget _buildAnswerStatusIcon() {
    if (!_hasGradableField(_current)) {
      return Icon(Icons.help_outline, size: context.icon(20), color: Colors.grey[400]);
    }
    final correct = _isCurrentAnswerCorrect(_current);
    return Icon(
      correct ? Icons.check_circle : Icons.cancel,
      size: context.icon(20),
      color: correct ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
    );
  }

  Widget _buildFieldDisplay(FieldDefinition field) {
    switch (field.type) {
      case FieldType.text:
        final value = _current.question.textFor(field.id);
        if (value == null || value.isEmpty) return const SizedBox.shrink();
        return MarkdownText(
          text: value,
          style: TextStyle(fontSize: 14, color: context.colors.text),
        );
      case FieldType.image:
        final path = _current.question.textFor(field.id);
        if (path == null) return const SizedBox.shrink();
        if (field.maxWidth == null && field.maxHeight == null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(path), width: double.infinity, fit: BoxFit.cover),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: field.maxWidth ?? double.infinity,
              maxHeight: field.maxHeight ?? double.infinity,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        );
      case FieldType.audio:
        final path = _current.question.textFor(field.id);
        if (path == null) return const SizedBox.shrink();
        final playing = _playingFieldId == field.id;
        return Center(
          child: IconButton(
            iconSize: context.icon(64),
            icon: Icon(playing ? Icons.stop_circle : Icons.play_circle, color: context.colors.accent),
            onPressed: () => _toggleAudio(field.id, path),
          ),
        );
      case FieldType.options:
        return _isMultiSelect(_current, field)
            ? _buildMultiSelectDisplay(field)
            : _buildOptionsDisplay(field);
      case FieldType.vof:
        return _buildMultiSelectDisplay(field);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOptionsDisplay(FieldDefinition field) {
    final options = _optionsFor(field);
    final selected = _selectedOptionByField[field.id];

    return Column(
      children: List.generate(options.length, (i) {
        final option = options[i];
        final isSelected = selected == i;

        Color borderColor = context.colors.border;
        Color bgColor = context.colors.surface;

        if (_answered) {
          if (option.correct) {
            borderColor = const Color(0xFF2E7D32);
            bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.08);
          } else if (isSelected && !option.correct) {
            borderColor = const Color(0xFFC62828);
            bgColor = const Color(0xFFC62828).withValues(alpha: 0.08);
          }
        } else if (isSelected) {
          borderColor = const Color(0xFF2E7D32);
          bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.08);
        }

        return GestureDetector(
          onTap: _answered ? null : () => setState(() => _selectedOptionByField[field.id] = i),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Text(option.text, style: TextStyle(fontSize: 14, color: context.colors.text)),
          ),
        );
      }),
    );
  }

  Widget _buildMultiSelectDisplay(FieldDefinition field) {
    final options = _optionsFor(field);
    final answers = _vofAnswersByField.putIfAbsent(field.id, () => {});

    return Column(
      children: List.generate(options.length, (i) {
        final option = options[i];
        final isMarked = answers[i] == true;

        Color borderColor = context.colors.border;
        Color bgColor = context.colors.surface;

        if (_answered) {
          borderColor = option.correct ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
          bgColor = isMarked
              ? const Color(0xFF2E7D32).withValues(alpha: 0.08)
              : const Color(0xFFC62828).withValues(alpha: 0.08);
        } else if (isMarked) {
          borderColor = const Color(0xFF2E7D32);
          bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.08);
        }

        return GestureDetector(
          onTap: _answered
              ? null
              : () => setState(() {
                    if (answers[i] == true) {
                      answers.remove(i);
                    } else {
                      answers[i] = true;
                    }
                  }),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Text(option.text, style: TextStyle(fontSize: 14, color: context.colors.text)),
          ),
        );
      }),
    );
  }

  Widget _buildExtraComments() {
    if (_current.question.extraComments.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.note,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
      ),
      child: Text(_current.question.extraComments, style: TextStyle(fontSize: 13, color: context.colors.text)),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Container(
        color: context.colors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _centered(!_answered
          ? _fullWidthButton('Mostrar Resposta', _showAnswer)
          : _hasGradableField(_current)
              ? _fullWidthButton('Continuar', () => _registerAndNext(_isCurrentAnswerCorrect(_current)))
              : Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _registerAndNext(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFC62828)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('FALHA'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _registerAndNext(true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CORRETO'),
                    ),
                  ),
                ]),
        maxWidth: 350,
        ),
      ),
    );
  }

  static const double _contentMaxWidth = 720;

  Widget _centered(Widget child, {double maxWidth = _contentMaxWidth}) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  Widget _fullWidthButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
