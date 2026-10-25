import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../styles/app_theme.dart';

const List<String> kMonthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const List<String> kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> kWeekdayLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const Color _kDown = Color(0xFFC62828);

String formatDay(DateTime d) => '${d.day} ${kMonthNames[d.month - 1]} ${d.year}';
String formatDayShort(DateTime d) => '${d.day} ${kMonthNames[d.month - 1]}';
String formatMonth(DateTime d) => '${kMonthNames[d.month - 1]} ${d.year}';

/// 1234567 -> 1,234,567
String formatCount(num n) {
  final digits = n.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0 && digits[i - 1] != '-') buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String formatAverage(double v) => v >= 10 ? formatCount(v) : v.toStringAsFixed(1);

String formatDays(int n) => '${formatCount(n)} ${n == 1 ? 'day' : 'days'}';

/// Cartão com título e ícone que agrupa uma seção.
class StatCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;

  const StatCard({super.key, required this.title, required this.child, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: context.icon(20), color: c.accent),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Número grande com rótulo. [outlined]: borda em vez de fundo (para uso dentro de um StatCard).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final bool outlined;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: outlined ? null : c.surfaceAlt,
        border: outlined ? Border.all(color: c.border) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.mutedText)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c.text)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: TextStyle(fontSize: 11, color: c.mutedText)),
          ],
        ],
      ),
    );
  }
}

/// Lista de [StatTile] em duas colunas, com linhas da mesma altura.
class StatGrid extends StatelessWidget {
  final List<Widget> children;
  const StatGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// Linha "rótulo ........ valor".
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  const StatRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.mutedText))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de período: valor atual e variação (%) em relação ao período anterior.
class PeriodRow extends StatelessWidget {
  final String label;
  final int value;
  final int previous;
  const PeriodRow({super.key, required this.label, required this.value, required this.previous});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    String delta = '';
    Color color = c.mutedText;
    if (previous > 0) {
      final pct = ((value - previous) / previous * 100).round();
      delta = '${pct > 0 ? '▲' : (pct < 0 ? '▼' : '•')} ${pct.abs()}%';
      color = pct > 0 ? c.accent : (pct < 0 ? _kDown : c.mutedText);
    } else if (value > 0) {
      delta = 'new';
      color = c.accent;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.mutedText))),
          Text(formatCount(value),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
          SizedBox(
            width: 70,
            child: Text(delta,
              textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Gráfico de barras simples (sem dependências). Toque/segure numa barra mostra o valor.
class BarChart extends StatelessWidget {
  final List<num> values;
  final List<String>? labels; // um por barra (abaixo do gráfico)
  final List<String>? tooltips; // um por barra
  final int? highlight; // barra em destaque (as outras ficam mais claras)
  final String? footerStart;
  final String? footerEnd;
  final double height;

  const BarChart({
    super.key,
    required this.values,
    this.labels,
    this.tooltips,
    this.highlight,
    this.footerStart,
    this.footerEnd,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxValue = values.fold<double>(0, (m, v) => math.max(m, v.toDouble()));
    final gap = values.length > 14 ? 1.0 : 3.0;

    final bars = <Widget>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i].toDouble();
      final barHeight = (v <= 0 || maxValue <= 0) ? 2.0 : math.max(3.0, v / maxValue * height);
      final emphasized = highlight == null || highlight == i;
      Widget bar = Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: v <= 0 ? c.border : (emphasized ? c.accent : c.accent.withValues(alpha: 0.5)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      );
      if (tooltips != null) bar = Tooltip(message: tooltips![i], triggerMode: TooltipTriggerMode.tap, child: bar);
      bars.add(Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: gap), child: bar)));
    }

    return Column(
      children: [
        SizedBox(height: height, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: bars)),
        if (labels != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              for (final l in labels!)
                Expanded(
                  child: Text(l,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(fontSize: 10, color: c.mutedText)),
                ),
            ],
          ),
        ],
        if (footerStart != null || footerEnd != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(footerStart ?? '', style: TextStyle(fontSize: 10, color: c.mutedText)),
              Text(footerEnd ?? '', style: TextStyle(fontSize: 10, color: c.mutedText)),
            ],
          ),
        ],
      ],
    );
  }
}
