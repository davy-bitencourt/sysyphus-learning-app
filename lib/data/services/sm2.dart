/// Algoritmo SM-2 (repetição espaçada), versão binária: acertou / errou.
///
/// Acerto:
///   - 1ª revisão  -> 1 dia
///   - 2ª revisão  -> 6 dias
///   - demais      -> intervalo anterior x fator de facilidade (ease)
///   - o ease sobe 0.1 a cada acerto (limites 1.3 a 3.0)
/// Erro: quem trata é o QuestionDao.updateStateNeutral (volta a ficar
/// pendente na hora, com intervalo 0 e ease 2.4).
class Sm2Result {
  final int intervalDays;
  final double easeFactor;
  const Sm2Result(this.intervalDays, this.easeFactor);
}

class Sm2 {
  static const double minEase = 1.3;
  static const double maxEase = 3.0;
  static const double defaultEase = 2.4;

  static Sm2Result onCorrect({
    required int previousInterval,
    required double previousEase,
  }) {
    final int interval;
    if (previousInterval <= 0) {
      interval = 1;
    } else if (previousInterval == 1) {
      interval = 6;
    } else {
      interval = (previousInterval * previousEase).round();
    }
    final ease = (previousEase + 0.1).clamp(minEase, maxEase).toDouble();
    return Sm2Result(interval, ease);
  }
}
