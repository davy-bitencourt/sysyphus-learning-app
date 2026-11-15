import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sysyphus/widgets/quick_subject_dialog.dart';

void main() {
  testWidgets('formulário rápido exige título antes de acessar o banco', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showQuickSubjectDialog(context),
          child: const Text('Abrir'),
        )),
      ),
    ));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    // Não há dependência de SQLite neste teste: o título vazio é recusado
    // pelo validator antes de qualquer chamada ao PackageDao.
    await tester.tap(find.text('ux.create'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('pkg.nameRequired'), findsOneWidget);
    await tester.tap(find.text('common.cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
