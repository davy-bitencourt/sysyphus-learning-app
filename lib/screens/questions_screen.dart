import 'package:flutter/material.dart';
import 'package:sysyphus_learning_app/data/DAO/template_dao.dart';

enum QuestionType { open, multiple, vof }

class QuestionOption {
  final String text;
  final bool correct;
  const QuestionOption({required this.text, required this.correct});
}

class Question {
  final String statement;       
  final QuestionType type;      
  final List<QuestionOption> options; 
  final String? suggestion;     
  final String extraComments;   

  const Question({
    required this.statement,
    required this.type,
    required this.extraComments,
    this.options = const [],
    this.suggestion,
  });
}

final List<Question> _mockQuestions = [
  Question(
    statement: 'Qual é a capital do Brasil?',
    type: QuestionType.multiple,
    extraComments: 'Brasília foi inaugurada em 1960 e substituiu o Rio de Janeiro como capital federal.',
    options: [
      const QuestionOption(text: 'Brasília',      correct: true),
      const QuestionOption(text: 'São Paulo',     correct: false),
      const QuestionOption(text: 'Rio de Janeiro',correct: false),
      const QuestionOption(text: 'Salvador',      correct: false),
    ],
  ),
  Question(
    statement: 'Explique com suas palavras o que é recursão.',
    type: QuestionType.open,
    suggestion: 'Recursão é quando uma função chama a si mesma para resolver subproblemas menores até atingir um caso base.',
    extraComments: 'Exemplos clássicos: fatorial, Fibonacci, busca em árvores.',
  ),
  Question(
    statement: 'Classifique as afirmações como Verdadeiro ou Falso:',
    type: QuestionType.vof,
    extraComments: 'A Terra orbita o Sol (V). O Sol orbita a Terra (F).',
    options: [
      const QuestionOption(text: 'A Terra orbita o Sol',  correct: true),
      const QuestionOption(text: 'O Sol orbita a Terra',  correct: false),
      const QuestionOption(text: 'A Lua orbita a Terra',  correct: true),
      const QuestionOption(text: 'Marte tem dois satélites', correct: true),
    ],
  ),
];

class QuestionScreen extends StatefulWidget {
  final List<Question>? questions;

  const QuestionScreen({
    super.key,
    this.questions,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int _currentQuestion = 0;
  late final List<Question> _questions = widget.questions ?? _mockQuestions;
  
  int? _selectedOption;
  
  final Map<int, bool> _vofAnswers = {};

  bool _answered = false; 

  Question get _question => _questions[_currentQuestion];

  void _showAnswer() {
    if (_question.type == QuestionType.multiple && _selectedOption == null) return;
    setState(() => _answered = true);
  }

  void _next(bool passed) {
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

  @override
  Widget build(BuildContext context) {
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
        if (_answered && _question.suggestion != null) ...[
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
        Widget? trailingIcon;
        
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
                if (trailingIcon != null) trailingIcon,
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
          ? Row(children: [
              
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _next(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continuar', style: TextStyle(fontSize: 15)),
                ),
              ),
            ])
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