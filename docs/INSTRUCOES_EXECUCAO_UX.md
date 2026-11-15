# Guia de execução e verificação no Windows

## 1. Preparar o projeto

1. Extraia o ZIP para uma pasta, por exemplo, `C:\Projetos\sysyphus-ux`.
2. No Visual Studio Code, selecione **Arquivo > Abrir Pasta** e escolha a pasta extraída.
3. Verifique se o Flutter SDK está instalado e configurado no PATH com:

```powershell
flutter doctor
flutter --version
```

4. Abra **Terminal > Novo Terminal** dentro da pasta que contém `pubspec.yaml`.
5. Execute:

```powershell
flutter pub get
```

## 2. Preparar e executar no Google Chrome

O Sysyphus utiliza SQLite via `sqflite_common_ffi_web`. Os arquivos `web/sqflite_sw.js` e `web/sqlite3.wasm` já acompanham este ZIP. Se precisar recriá-los para a sua versão instalada das dependências, use:

```powershell
dart run sqflite_common_ffi_web:setup
```

Execute o aplicativo:

```powershell
flutter run -d chrome
```

Se necessário, execute primeiro `flutter devices` para verificar se o Chrome aparece entre os dispositivos disponíveis. Use `flutter clean` e `flutter pub get` se restarem artefatos incompatíveis de uma compilação anterior. A primeira utilização do banco Web depende de o navegador permitir IndexedDB e carregamento do Web Worker.

## 3. Testes automatizados

Na pasta raiz do projeto:

```powershell
flutter analyze
flutter test
```

Em seguida, se houver um dispositivo Android:

```powershell
flutter devices
flutter run -d <identificador_do_dispositivo>
```

Não use os resultados desses comandos como aprovados até executá-los na sua máquina.

## 4. Roteiro manual de UX

1. Abra a tela inicial e pressione "Nova matéria".
2. Pressione "Criar" sem informar título. Verifique se a validação impede o cadastro.
3. Informe `Matemática` e escolha "Criar e adicionar questão".
4. No editor de questão aberta, informe pergunta e resposta, adicione uma explicação opcional e salve.
5. Volte à home e confirme que a matéria e o contador aparecem atualizados.
6. Na mesma matéria, pressione "Adicionar questão", selecione "Múltipla escolha", preencha ao menos duas alternativas, marque apenas uma correta e salve.
7. Crie uma questão de "Verdadeiro ou falso", selecione a resposta correta e salve.
8. Pressione "Estudar" e verifique que as questões aparecem, que as alternativas funcionam e que a explicação é exibida após responder.
9. Pressione "Ver e editar questões", edite uma questão e confirme que a alteração persiste depois de fechar e reabrir o aplicativo.
10. No menu da matéria, edite o título e teste a exclusão mediante confirmação, preferencialmente com uma matéria descartável.
11. Repita a criação com teclado virtual aberto e em uma janela estreita de Chrome. Verifique rolagem, áreas de toque e eventuais overflows.
12. Altere o idioma nas configurações para inglês, espanhol e japonês. Verifique os textos dos novos formulários. Algumas telas antigas ainda aparecem parcialmente em inglês nos dois últimos idiomas.
13. Feche e reabra o aplicativo no mesmo navegador e perfil. Verifique que os registros permanecem presentes.

**Atenção:** não limpe os dados do site ou IndexedDB do Chrome se desejar preservar seu banco local. O armazenamento do Chrome não é compartilhado automaticamente com o de um aplicativo Android.

## 5. Código-fonte e organização

As alterações relevantes são descritas em `docs/RELATORIO_COMPARATIVO_UX.md`. Consulte também as instruções originais `INSTRUCOES_WEB_WINDOWS.md` e `RELATORIO_TECNICO_WEB.md` para a configuração do SQLite Web.
