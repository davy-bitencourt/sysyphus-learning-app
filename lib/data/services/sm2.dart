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
