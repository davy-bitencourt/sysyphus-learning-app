import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../styles/app_theme.dart';

class MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const MarkdownText({super.key, required this.text, required this.style});

  Future<void> _openLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) return;
    final uri = Uri.tryParse(href.startsWith('http') ? href : 'https://$href');
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = style.fontSize ?? 14;

    final sheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: style,
      listBullet: style,
      a: TextStyle(
        color: c.accent,
        decoration: TextDecoration.underline,
        decorationColor: c.accent,
      ),
      h1: style.copyWith(fontSize: size + 6, fontWeight: FontWeight.bold),
      h2: style.copyWith(fontSize: size + 4, fontWeight: FontWeight.bold),
      h3: style.copyWith(fontSize: size + 2, fontWeight: FontWeight.bold),
      blockquote: style.copyWith(color: c.mutedText),
      blockquotePadding: const EdgeInsets.only(left: 12),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: c.accent, width: 3)),
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: size * 0.9,
        color: c.text,
        backgroundColor: c.surfaceAlt,
      ),
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return MarkdownBody(
      data: text,
      styleSheet: sheet,
      softLineBreak: true,
      onTapLink: (_, href, __) => _openLink(context, href),
      imageBuilder: (uri, title, alt) => Text(alt ?? '', style: style),
    );
  }
}
