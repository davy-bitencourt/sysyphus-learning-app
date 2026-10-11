import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/transfer/pack_exporter.dart';
import '../data/transfer/pack_importer.dart';
import '../data/transfer/pack_models.dart';
import '../data/transfer/pack_parser.dart';
import '../styles/app_theme.dart';
import 'home.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _today() {
  final d = DateTime.now();
  return '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

String _outcomeText(ImportOutcome o) {
  final parts = <String>['${o.questionsAdded} questões'];
  if (o.packagesCreated > 0) parts.add('${o.packagesCreated} pacotes novos');
  if (o.templatesCreated > 0) parts.add('${o.templatesCreated} templates novos');
  if (o.sessionsCreated > 0) parts.add('${o.sessionsCreated} sessões novas');
  if (o.tagsCreated > 0) parts.add('${o.tagsCreated} tags novas');
  var text = 'Importado: ${parts.join(', ')}.';
  if (o.duplicatesSkipped > 0) text += ' ${o.duplicatesSkipped} já existiam e foram ignoradas.';
  return text;
}

// ---------------------------------------------------------------------------
// Importar
// ---------------------------------------------------------------------------

/// Escolhe o .zip, valida SEM gravar e abre a tela de resumo. Só grava se o
/// usuário confirmar. Devolve true se algo foi importado.
Future<bool> startPackImport(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Não foi possível abrir o seletor de arquivos: $e')));
    return false;
  }
  final path = picked?.files.single.path;
  if (path == null) return false;

  PackImportPlan? builtPlan;
  Map<String, List<int>>? unzipped;
  String? failure;
  try {
    final bytes = await File(path).readAsBytes();
    unzipped = unzipPack(bytes);
    builtPlan = await buildImportPlan(parsePack(unzipped));
  } on FormatException catch (e) {
    failure = e.message;
  } catch (e) {
    failure = 'Não foi possível ler o arquivo: $e';
  }

  final plan = builtPlan;
  final files = unzipped;
  if (failure != null || plan == null || files == null) {
    messenger.showSnackBar(SnackBar(content: Text(failure ?? 'Não foi possível ler o arquivo.')));
    return false;
  }

  final outcome = await navigator.push<ImportOutcome>(
    MaterialPageRoute(builder: (_) => ImportPreviewScreen(plan: plan, files: files)),
  );
  if (outcome == null) return false;

  Home.packagesChanged.value++; // a Home recarrega pacotes e contagens
  messenger.showSnackBar(SnackBar(content: Text(_outcomeText(outcome))));
  return true;
}

class ImportPreviewScreen extends StatefulWidget {
  final PackImportPlan plan;
  final Map<String, List<int>> files;

  const ImportPreviewScreen({super.key, required this.plan, required this.files});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  bool _importing = false;

  PackImportPlan get _plan => widget.plan;

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final outcome = await commitImport(_plan, widget.files);
      if (!mounted) return;
      Navigator.pop(context, outcome);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível importar (nada foi gravado): $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final errors = _plan.parsed.errors;
    final warnings = _plan.parsed.warnings;
    final canImport = errors.isEmpty && _plan.hasChanges && !_importing;
    final count = _plan.questionsToAdd.length;

    final String buttonLabel;
    if (_importing) {
      buttonLabel = 'Importando...';
    } else if (errors.isNotEmpty) {
      buttonLabel = 'Corrija os erros para importar';
    } else if (!_plan.hasChanges) {
      buttonLabel = 'Nada novo para importar';
    } else {
      buttonLabel = count > 0 ? 'Importar $count questões' : 'Importar';
    }

    return PopScope(
      canPop: !_importing,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c.text),
            onPressed: _importing ? null : () => Navigator.pop(context),
          ),
          title: Text('Importar pacote',
            style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 20)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummary(context),
            if (errors.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildIssues(
                context,
                title: 'Erros (${errors.length}) — corrija o arquivo e tente de novo',
                issues: errors,
                color: const Color(0xFFC62828),
                icon: Icons.error_outline,
              ),
            ],
            if (_plan.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildNotes(context),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildIssues(
                context,
                title: 'Avisos (${warnings.length})',
                issues: warnings,
                color: const Color(0xFFEF6C00),
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            color: c.bg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canImport ? _import : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(buttonLabel, style: const TextStyle(fontSize: 15)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final c = context.colors;
    final p = _plan;

    String join(List<String> parts) => parts.isEmpty ? 'nenhum' : parts.join(', ');

    final packages = join([
      if (p.packagesNew > 0) '${p.packagesNew} novos',
      if (p.packagesExisting > 0) '${p.packagesExisting} já existem (recebem as questões)',
    ]);
    final questions = join([
      '${p.questionsToAdd.length} a importar',
      if (p.duplicatesSkipped > 0) '${p.duplicatesSkipped} já existem (ignoradas)',
    ]);
    final templates = join([
      if (p.templatesNew > 0) '${p.templatesNew} novos',
      if (p.templatesReused > 0) '${p.templatesReused} reaproveitados',
      if (p.templatesCopied > 0) '${p.templatesCopied} cópias',
    ]);
    final sessions = join([
      if (p.sessionsNew > 0) '${p.sessionsNew} novas',
      if (p.sessionsExisting > 0) '${p.sessionsExisting} já existem',
    ]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('O que será importado',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.text)),
          const SizedBox(height: 10),
          _summaryRow(context, Icons.folder_outlined, 'Pacotes', packages),
          _summaryRow(context, Icons.quiz_outlined, 'Questões', questions),
          _summaryRow(context, Icons.dashboard_customize_outlined, 'Templates', templates),
          _summaryRow(context, Icons.timer_outlined, 'Sessões', sessions),
          _summaryRow(context, Icons.label_outline, 'Tags novas', '${p.tagsNew}'),
          _summaryRow(context, Icons.perm_media_outlined, 'Mídias', '${p.mediaToCopy.length} arquivos'),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, IconData icon, String label, String value) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.icon(18), color: c.accent),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(fontSize: 13, color: c.mutedText)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in _plan.notes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: context.icon(16), color: c.mutedText),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note, style: TextStyle(fontSize: 12, color: c.text))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIssues(
    BuildContext context, {
    required String title,
    required List<PackIssue> issues,
    required Color color,
    required IconData icon,
  }) {
    final c = context.colors;
    const maxShown = 40;
    final shown = issues.take(maxShown).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: context.icon(18), color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${issue.where}\n',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.mutedText),
                    ),
                    TextSpan(text: issue.message, style: TextStyle(fontSize: 12, color: c.text)),
                  ],
                ),
              ),
            ),
          if (issues.length > maxShown)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('... e mais ${issues.length - maxShown}',
                style: TextStyle(fontSize: 12, color: c.mutedText)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exportar
// ---------------------------------------------------------------------------

/// Gera o .zip com tudo (ou só [packageIds]) e pede onde salvar.
Future<void> startPackExport(BuildContext context, {Set<int>? packageIds}) async {
  final messenger = ScaffoldMessenger.of(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  ExportResult? export;
  String? buildError;
  try {
    export = await buildExport(packageIds: packageIds);
  } catch (e) {
    buildError = '$e';
  }
  rootNavigator.pop(); // fecha o indicador de progresso

  if (export == null) {
    messenger.showSnackBar(SnackBar(content: Text('Não foi possível exportar: $buildError')));
    return;
  }

  String? savedPath;
  String? saveError;
  try {
    savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Salvar exportação',
      fileName: 'sysyphus-${_today()}.zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: export.bytes,
    );
    // No desktop o seletor só devolve o caminho escolhido: grava os bytes.
    if (savedPath != null && !Platform.isAndroid) {
      await File(savedPath).writeAsBytes(export.bytes);
    }
  } catch (e) {
    saveError = '$e';
  }

  if (saveError != null) {
    messenger.showSnackBar(SnackBar(content: Text('Não foi possível salvar o arquivo: $saveError')));
    return;
  }
  if (savedPath == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Exportação cancelada.')));
    return;
  }

  messenger.showSnackBar(SnackBar(
    content: Text(
      'Exportado: ${export.questions} questões, ${export.packages} pacotes, '
      '${export.templates} templates, ${export.sessions} sessões, ${export.mediaFiles} mídias.',
    ),
  ));

  if (export.warnings.isNotEmpty && context.mounted) {
    final warnings = export.warnings;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Exportado com ${warnings.length} aviso(s)'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final w in warnings.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(w, style: const TextStyle(fontSize: 12)),
                ),
              if (warnings.length > 30) Text('... e mais ${warnings.length - 30}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
        ],
      ),
    );
  }
}
