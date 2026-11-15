import 'package:flutter/material.dart';

import '../data/DAO/package_dao.dart';
import '../l10n/strings.dart';

/// Resultado de uma matéria criada no banco de dados (não é apenas uma tela).
class QuickSubjectResult {
  final int id;
  final bool addQuestion;

  const QuickSubjectResult(this.id, {required this.addQuestion});
}

/// Criação com um único campo obrigatório. As opções avançadas de sessões
/// continuam disponíveis em PackageEditScreen ao editar a matéria.
Future<QuickSubjectResult?> showQuickSubjectDialog(
  BuildContext context, {bool allowAddQuestion = true}
) {
  return showDialog<QuickSubjectResult>(
    context: context,
    builder: (_) => _QuickSubjectDialog(allowAddQuestion: allowAddQuestion),
  );
}

class _QuickSubjectDialog extends StatefulWidget {
  final bool allowAddQuestion;

  const _QuickSubjectDialog({required this.allowAddQuestion});

  @override
  State<_QuickSubjectDialog> createState() => _QuickSubjectDialogState();
}

class _QuickSubjectDialogState extends State<_QuickSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create({required bool addQuestion}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final id = await PackageDao().insert(null, _titleController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(QuickSubjectResult(id, addQuestion: addQuestion));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = context.tr('pkg.saveFailed', {'error': error});
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(context.tr('ux.newSubject')),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _create(addQuestion: false),
                  decoration: InputDecoration(
                    labelText: context.tr('ux.subjectTitle'),
                    hintText: context.tr('ux.subjectExample'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? context.tr('pkg.nameRequired') : null,
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 8),
                  Text(_saveError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: _saving ? null : () => _create(addQuestion: false),
            child: Text(context.tr('ux.create')),
          ),
          if (widget.allowAddQuestion) FilledButton.icon(
            onPressed: _saving ? null : () => _create(addQuestion: true),
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add),
            label: Text(context.tr('ux.createAndQuestion')),
          ),
        ],
      ),
    );
  }
}
