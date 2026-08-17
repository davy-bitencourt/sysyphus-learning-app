import 'package:flutter/material.dart';
import 'package:sysyphus_learning_app/data/schema/question_schema.dart';
import 'package:sysyphus_learning_app/data/schema/template_schema.dart';
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

  List<Question> _questions = [];
  bool _loading = true;

  int _currentQuestion = 0;
  int? _selectedOption;
  final Map<int, bool> _vofAnswers = {};
  bool _answered = false;

  Question get _question => _questions[_currentQuestion];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);

    await _questionSchema.getQuestionData(widget.packageId, widget.limit);

    final questions = <Question>[];
    for (final row in _questionSchema.question_schema) {
      final templateId = row['template_id'] as int?;
      if (templateId == null) continue;

      await _templateSchema.isOnCache(templateId);
      final templateJson = _templateSchema.template_schema[templateId];
      if (templateJson == null) continue;

      final template = TemplateModel(
        id: templateId,
        type: questionTypeFromString(templateJson['type'] as String? ?? 'open'),
        optionCount: templateJson['optionCount'] as int? ?? 4,
      );

      questions.add(Question.fromDb(row, template));
    }

    if (!mounted) return;
    setState(() {
      _questions = questions;
      _currentQuestion = 0;
      _selectedOption = null;
      _vofAnswers.clear();
      _answered = false;
      _loading = false;
    });
  }

  void _showAnswer() {
    if (_question.type == QuestionType.multiple && _selectedOption == null) return;
    setState(() => _answered = true);
  }

  void _next() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
        _selectedOption = null;
        _vofAnswers.clear();
        _answered = false;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _openNewQuestion() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionsEditScreen(packageId: widget.packageId),
      ),
    );
    if (result == true) _loadQuestions();
  }

  Future<void> _openEditQuestion() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionsEditScreen(
          question: _question,
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
                Text('Nenhuma questão neste pacote ainda.',
                  style: TextStyle(color: Colors.grey[600])),
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
        title: Text(
          '${_currentQuestion + 1} / ${_questions.length}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
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
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
            child: SizedBox(
              width: 80,
              child: LinearProgressIndicator(
                value: (_currentQuestion + 1) / _questions.length,
                backgroundColor: const Color(0xFFE0E0E0),
                color: const Color(0xFFE65100),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _question.statement,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E)),
              ),
            ),
            const SizedBox(height: 16),
            _buildQuestionBody(),
            const SizedBox(height: 16),
            if (_answered) _buildExtraComments(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooter(),
    );
  }

  Widget _buildQuestionBody() {
    switch (_question.type) {
      case QuestionType.open:
        return _buildOpenQuestion();
      case QuestionType.multiple:
        return _buildMultipleChoice();
      case QuestionType.vof:
        return _buildVof();
    }
  }

  Widget _buildOpenQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: const Text(
            'Questão aberta',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        if (_answered && (_question.suggestion?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_question.suggestion!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultipleChoice() {
    return Column(
      children: List.generate(_question.options.length, (i) {
        final option = _question.options[i];
        final selected = _selectedOption == i;

        Color borderColor = const Color(0xFFE0E0E0);
        Color bgColor = Colors.white;

        if (_answered) {
          if (option.correct) {
            borderColor = const Color(0xFF2E7D32);
            bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.08);
          } else if (selected && !option.correct) {
            borderColor = const Color(0xFFC62828);
            bgColor = const Color(0xFFC62828).withValues(alpha: 0.08);
          }
        } else if (selected) {
          borderColor = const Color(0xFF2E7D32);
          bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.08);
        }

        return GestureDetector(
          onTap: _answered ? null : () => setState(() => _selectedOption = i),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(option.text,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildVof() {
    return Column(
      children: List.generate(_question.options.length, (i) {
        final option = _question.options[i];
        final isMarked = _vofAnswers[i] == true;

        Color borderColor = const Color(0xFFE0E0E0);
        Color bgColor = Colors.white;

        if (_answered) {
          borderColor = option.correct
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828);
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
                    if (_vofAnswers[i] == true) {
                      _vofAnswers.remove(i);
                    } else {
                      _vofAnswers[i] = true;
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
            child: Text(option.text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E))),
          ),
        );
      }),
    );
  }

  Widget _buildExtraComments() {
    if (_question.extraComments.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_question.extraComments,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E))),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _answered
          ? SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continuar', style: TextStyle(fontSize: 15)),
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mostrar Resposta', style: TextStyle(fontSize: 15)),
              ),
            ),
    );
  }
}
