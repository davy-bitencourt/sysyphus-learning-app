# Sysyphus Learning App: executar no Google Chrome

## Pré-requisitos

- Windows 10/11 com Flutter SDK instalado, Dart acessível no PATH e Chrome instalado.
- Acesso à internet na primeira instalação das dependências e dos binários WebAssembly.
- Terminal do VS Code ou PowerShell **na pasta que contém `pubspec.yaml`**.

## Caminho mais simples

1. Extraia o ZIP completamente.
2. Abra `sysyphus-learning-app-main` no Visual Studio Code.
3. Execute `INICIAR_WEB.bat` pelo Explorador de Arquivos ou terminal.

O arquivo `.bat` executa `flutter pub get`, gera os binários de SQLite Web, confirma sua presença e inicia o app no Chrome usando uma porta fixa para preservar os dados entre as execuções. **É importante utilizar o `.bat` pelo menos na primeira execução, ou executar manualmente o comando de setup.**

## Passo a passo manual no PowerShell

```powershell
flutter doctor
flutter clean
flutter pub get
dart run sqflite_common_ffi_web:setup
flutter analyze
flutter test
flutter build web
flutter run -d chrome --web-port=7357
```

Se quiser usar exatamente `flutter run -d chrome`, **ele funciona somente depois da preparação do SQLite Web**. Além disso, sem uma porta fixa, o Flutter pode escolher outra porta e o navegador tratará o aplicativo como uma origem diferente, com outro banco IndexedDB. Prefira sempre `--web-port=7357` ao trabalhar com dados locais.

Para novas execuções após a preparação:

```powershell
flutter run -d chrome --web-port=7357
```

**Não execute `flutter create .` automaticamente.** Não apague dados do site no Chrome, nem limpe o armazenamento do navegador se quiser preservar os estudos locais. A versão para navegador usa banco próprio por origem (protocolo, hostname e porta). O banco da versão Windows não é transferido automaticamente para a Web. Use a importação/exportação do app para mover conteúdo entre instalações, conforme as funcionalidades suportadas.

## Verificação dos arquivos do SQLite

Depois de executar `dart run sqflite_common_ffi_web:setup`, confirme que existem:

```text
web/sqlite3.wasm
web/sqflite_sw.js
```

Se houver uma atualização do `sqflite_common_ffi_web`, atualize os binários com `dart run sqflite_common_ffi_web:setup --force` e valide a compilação.

## Testes de aceitação recomendados

1. Abra o app no Chrome e confirme que a tela inicial aparece.
2. Crie uma matéria e uma questão, feche o Chrome, execute novamente na **mesma porta** e confira se foram preservadas.
3. Edite, exclua e estude uma questão.
4. Teste a adição e reprodução de imagem/áudio, importação e exportação ZIP.
5. Troque entre português e inglês nas configurações.
6. Se usa sincronização com o aplicativo desktop, crie o host no desktop e entre na Web usando o endereço IP. A conexão está sujeita às permissões de rede e CORS do navegador. A versão Web não hospeda servidor UDP/TCP e não faz descoberta de hosts por broadcast.

Se houver tela branca, abra `F12` (Console e Rede) e verifique falhas ao carregar `sqlite3.wasm` e `sqflite_sw.js`. Execute `flutter analyze` e envie o erro completo do terminal para diagnóstico. Não desabilite recursos de segurança do navegador.

**Limitação desta entrega:** Flutter e Dart não estavam instalados no ambiente onde o ZIP foi preparado. Assim, não foi possível gerar os dois binários, executar a análise do Dart, compilar, rodar testes Flutter ou abrir o Chrome. As alterações são uma implementação a ser verificada localmente, não uma garantia de execução validada.

## Caso a execução anterior tenha mostrado uma tela branca

O PowerShell fornecido neste atendimento registrou `An error occurred while initializing the web worker` e a falta de `sqflite_sw.js`. A pasta `web/` do ZIP não possuía `sqflite_sw.js` nem `sqlite3.wasm`. Estes arquivos **não podem ser substituídos por arquivos JavaScript vazios**: são binários reais gerados pelo utilitário do pacote.

Execute primeiro `INICIAR_WEB.bat`, ou no PowerShell: `dart run sqflite_common_ffi_web:setup`. Em seguida, verifique os arquivos com:

```powershell
Test-Path .\web\sqflite_sw.js
Test-Path .\web\sqlite3.wasm
```

Os dois comandos devem retornar `True`. Se o setup falhar, envie a mensagem de erro. Depois que o SQLite estiver configurado, o aplicativo exibirá uma tela de carregamento e poderá mostrar uma mensagem de diagnóstico se a abertura do banco ainda falhar, em vez de ficar apenas em branco.

**Este ZIP não contém os binários gerados** porque Dart/Flutter não estão instalados no ambiente de preparação. O script precisa ser executado no computador Windows com acesso às dependências. Não foi possível validar a abertura do aplicativo no Chrome neste ambiente.
