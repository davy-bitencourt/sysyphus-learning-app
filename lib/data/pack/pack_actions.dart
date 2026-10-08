import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'pack_exporter.dart';
import 'pack_importer.dart';

/// Chame a partir de um botão na tela Database.
Future<bool> importPackFlow(BuildContext context) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['zip'],
    withData: true,
  );
  final bytes = picked?.files.single.bytes;
  if (bytes == null || !context.mounted) return false;

  PackPreview pv;
  try {
    pv = await PackImporter.preview(bytes);
  } catch (e) {
    if (context.mounted) _msg(context, 'Falha ao ler o ZIP: $e');
    return false;
  }
  if (!context.mounted) return false;

  final ok = pv.report.ok;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ok ? 'Importar?' : 'Importação bloqueada'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pv.summary),
            if (pv.report.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Erros', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final e in pv.report.errors.take(40)) Text('• $e', style: const TextStyle(fontSize: 12)),
              if (pv.report.errors.length > 40) Text('… e mais ${pv.report.errors.length - 40}'),
            ],
            if (pv.report.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Avisos', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final w in pv.report.warnings.take(20)) Text('• $w', style: const TextStyle(fontSize: 12)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ok ? 'Cancelar' : 'Fechar')),
        if (ok) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importar')),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return false;

  try {
    final r = await PackImporter.commit(pv.data);
    if (context.mounted) {
      _msg(context, '${r.questions} questões importadas'
          '${r.skippedQuestions > 0 ? ' (${r.skippedQuestions} já existiam)' : ''}, '
          '${r.packagesCreated} pacotes, ${r.templatesCreated} templates, ${r.media} mídias.');
    }
    return true;
  } catch (e) {
    if (context.mounted) _msg(context, 'Nada foi gravado. Erro: $e');
    return false;
  }
}

Future<void> exportPackFlow(BuildContext context, {List<int>? packageIds}) async {
  try {
    final res = await PackExporter.build(packageIds: packageIds);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final f = File('${dir.path}/sysyphus-$stamp.zip');
    await f.writeAsBytes(res.bytes);
    await Share.shareXFiles([XFile(f.path)], text: 'Backup Sysyphus (${res.summary})');
    if (context.mounted && res.warnings.isNotEmpty) {
      _msg(context, '${res.warnings.length} avisos na exportação: ${res.warnings.first}');
    }
  } catch (e) {
    if (context.mounted) _msg(context, 'Erro ao exportar: $e');
  }
}

void _msg(BuildContext c, String s) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 6)));
