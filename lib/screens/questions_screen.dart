import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:sysyphus_learning_app/data/schema/question_schema.dart';
import 'package:sysyphus_learning_app/data/schema/template_schema.dart';
import 'package:sysyphus_learning_app/data/DAO/question_state_dao.dart';
import 'package:sysyphus_learning_app/data/DAO/revlog_dao.dart';
import 'package:sysyphus_learning_app/data/models/field_model.dart';
import 'package:sysyphus_learning_app/data/models/question_model.dart';
import 'questions_edit_screen.dart';

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

  final Map<String, int?> _selectedOptionByField = {};
  final Map<String, Map<int, bool>> _vofAnswersByField = {};

  // Embaralha as alternativas de múltipla escolha para efetivar o estudo.
  // A chave inclui o índice da questão para que o embaralhamento seja
  // recalculado a cada nova questão, mas fique estável durante rebuilds.
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
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);

    await _questionSchema.getQuestionData(widget.packageId, widget.limit);

    final loaded = <LoadedQuestion>[];
    for (final row in _questionSchema.question_schema) {
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
  }

  void _resetAnswerState() {
    _answered = false;
    _selectedOptionByField.clear();
    _vofAnswersByField.clear();
    _playingFieldId = null;
  }

  bool _hasGradableField(LoadedQuestion q) =>
      q.template.fields.any((f) => f.type == FieldType.options || f.type == FieldType.vof);

  bool _isCurrentAnswerCorrect(LoadedQuestion q) {
    bool anyGraded = false;
    for (final field in q.template.fields) {
      if (field.type == FieldType.options) {
        anyGraded = true;
        final options = _optionsFor(field);
        final selected = _selectedOptionByField[field.id];
        if (selected == null || selected >= options.length || !options[selected].correct) {
          return false;
        }
      } else if (field.type == FieldType.vof) {
        anyGraded = true;
        final options = q.question.optionsFor(field.id);
        final answers = _vofAnswersByField[field.id] ?? {};
        for (int i = 0; i < options.length; i++) {
          final marked = answers[i] == true;
          if (marked != options[i].correct) return false;
        }
      }
    }
    return anyGraded;
  }

  void _showAnswer() => setState(() => _answered = true);

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Grava a revisão em `revlog` (alimenta o heatmap) e avança o estado
  /// de repetição espaçada em `state`.
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
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Nenhuma questão neste pacote ainda.', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _openNewQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        // Contador de questão e barra de progresso ficam juntos e
        // centralizados na app bar; os ícones de ação vão à direita.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_currentQuestion + 1} / ${_questions.length}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF555555))),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: LinearProgressIndicator(
                value: (_currentQuestion + 1) / _questions.length,
                backgroundColor: const Color(0xFFE0E0E0),
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A1A2E)),
            onPressed: _openEditQuestion,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF1A1A2E)),
            onPressed: _openNewQuestion,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Text(_current.question.statement,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
            ),
            const SizedBox(height: 16),
            ..._current.template.questionFields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildFieldDisplay(f),
                )),
            if (_answered) ...[
              if (_current.template.answerFields.isNotEmpty || _current.question.extraComments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Divider(color: Color(0xFFE0E0E0), thickness: 1.5)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.check_circle_outline, size: 16, color: Colors.grey[400]),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE0E0E0), thickness: 1.5)),
                ]),
                const SizedBox(height: 16),
              ],
              ..._current.template.answerFields.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildFieldDisplay(f),
                  )),
              _buildExtraComments(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildFieldDisplay(FieldDefinition field) {
    switch (field.type) {
      case FieldType.text:
        final value = _current.question.textFor(field.id);
        if (value == null || value.isEmpty) return const SizedBox.shrink();
        return Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)));
      case FieldType.image:
        final path = _current.question.textFor(field.id);
        if (path == null) return const SizedBox.shrink();
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(path), width: double.infinity, fit: BoxFit.cover),
        );
      case FieldType.audio:
        final path = _current.question.textFor(field.id);
        if (path == null) return const SizedBox.shrink();
        final playing = _playingFieldId == field.id;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(children: [
            IconButton(
              icon: Icon(playing ? Icons.stop_circle : Icons.play_circle, color: const Color(0xFFE65100), size: 32),
              onPressed: () => _toggleAudio(field.id, path),
            ),
            Expanded(child: Text(field.label, style: const TextStyle(fontSize: 13))),
          ]),
        );
      case FieldType.options:
        return _buildOptionsDisplay(field);
      case FieldType.vof:
        return _buildVofDisplay(field);
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

        Color borderColor = const Color(0xFFE0E0E0);
        Color bgColor = Colors.white;

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
            // Expande horizontalmente até a margem; só cresce verticalmente
            // conforme o texto da alternativa precisar de mais espaço.
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Text(option.text, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
          ),
        );
      }),
    );
  }

  Widget _buildVofDisplay(FieldDefinition field) {
    final options = _current.question.optionsFor(field.id);
    final answers = _vofAnswersByField.putIfAbsent(field.id, () => {});

    return Column(
      children: List.generate(options.length, (i) {
        final option = options[i];
        final isMarked = answers[i] == true;

        Color borderColor = const Color(0xFFE0E0E0);
        Color bgColor = Colors.white;

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
            child: Text(option.text, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
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
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
      ),
      child: Text(_current.question.extraComments, style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E))),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: !_answered
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
                      child: const Text('Não lembrei'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _registerAndNext(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Lembrei'),
                    ),
                  ),
                ]),
      ),
    );
  }

  Widget _fullWidthButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE65100),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}
