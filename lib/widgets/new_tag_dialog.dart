import 'package:flutter/material.dart';
import '../data/DAO/tag_dao.dart';
import '../styles/app_theme.dart';

/// Abre o diálogo de nova tag.
///
/// Ao salvar, a tag é criada e o diálogo continua aberto com o campo vazio,
/// para cadastrar a próxima (mesmo comportamento das telas de questão, pacote,
/// template e sessão). "Concluir" fecha o diálogo.
///
/// Quem chama deve recarregar suas listas depois do `await`, já que o diálogo
/// pode ser fechado tocando fora ou com o botão voltar.
Future<void> showNewTagDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _NewTagDialog(),
  );
}

class _NewTagDialog extends StatefulWidget {
  const _NewTagDialog();

  @override
  State<_NewTagDialog> createState() => _NewTagDialogState();
}

class _NewTagDialogState extends State<_NewTagDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _saving = false;
  String? _message; // confirmação ou erro da última tentativa
  bool _messageIsError = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final title = _controller.text.replaceAll('#', '').trim();
    if (title.isEmpty) {
      setState(() {
        _message = 'Digite o nome da tag.';
        _messageIsError = true;
      });
      _focusNode.requestFocus();
      return;
    }

    setState(() => _saving = true);
    try {
      await TagDao().insert(title);
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _message = 'Tag #$title salva.';
        _messageIsError = false;
      });
    } catch (e) {
      debugPrint('Erro ao salvar tag "$title": $e');
      if (!mounted) return;
      setState(() {
        _message = 'Não foi possível salvar a tag.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(hintText: 'Nome da tag (sem #)'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: TextStyle(
                fontSize: 12,
                color: _messageIsError ? const Color(0xFFC62828) : context.colors.mutedText,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Concluir'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
