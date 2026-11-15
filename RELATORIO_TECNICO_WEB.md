# Relatório técnico: adaptação para Flutter Web

Data da revisão: 15/11/2026. Base: `Sysyphus_Learning_App_Revisado(1).zip`.

## Problemas confirmados na inspeção

1. O `lib/main.dart` importava `dart:io` e decidia o uso de SQLite pelo `Platform`, incompatível com compilação Web.
2. A aplicação não configurava `databaseFactoryFfiWeb` nem declarava `sqflite_common_ffi_web`. Os arquivos `web/sqlite3.wasm` e `web/sqflite_sw.js` não estavam no ZIP.
3. `database_helper.dart` consultava `Platform.isWindows` para construir caminhos de banco, sem alternativa explícita para IndexedDB.
4. Seleção, gravação, leitura e exibição de mídias dependiam de `File`, `Image.file` e `path_provider`, APIs inexistentes ou inadequadas no navegador.
5. A importação de pacotes ZIP dependia de `File(path)` e a exportação exigia um caminho de arquivo gravável.
6. Serviço de sincronização, descoberta e HTTP usavam sockets `dart:io`, sem separação por plataforma. O servidor nativo não respondia às requisições CORS OPTIONS usadas pelos navegadores.
7. Os idiomas realmente existentes no ZIP são **português brasileiro e inglês**. Não foram encontrados arquivos de tradução espanhola ou japonesa.
8. `pubspec.lock` estava ausente, portanto a resolução exata das versões depende do Flutter/Dart local.

## Principais correções implementadas

| Área | Modificação |
| --- | --- |
| Entrada do aplicativo | `main.dart`: configuração condicional de SQLite nativo, desktop e Web, antes de qualquer acesso ao banco. |
| SQLite | `database_helper.dart`: banco `sysy_app.db` e versão 5 preservados; nome relativo apenas no navegador. |
| Plataforma | Novos adaptadores em `lib/data/platform/` para fábricas SQLite, arquivos locais e download ZIP. |
| Persistência de mídia | `media_storage_service.dart`: arquivos nativos mantidos; Web usa tabela auxiliar `web_media`, BLOB SQLite em IndexedDB e caminhos opacos; não apaga tabelas de estudo. |
| Mídia nas telas | `MediaImage`, renderização em memória e `BytesSource` para áudio Web no `questions_screen.dart` e `questions_edit_screen.dart`. |
| Pacotes ZIP | `pack_transfer.dart` e `pack_exporter.dart`: seleção baseada em bytes no browser, download sem caminho nativo e exportação de mídia pelo serviço abstrato. |
| Sincronização | `sync_service.dart` com implementação condicional: desktop/móvel mantém host e descoberta; Web é cliente HTTP com entrada manual de IP (o navegador não hospeda sockets). |
| Rede | `sync_http_server.dart` responde a preflight CORS; `sync_http_transport_web.dart` usa `http` para requisições assinadas. |
| Interface | `sync_settings_screen.dart` indica limites de sincronização Web, sem ocultar funções dos sistemas nativos. |
| Testes | `test/sync_http_test.dart` recebe teste de regressão para preflight CORS. |
| Execução | `INICIAR_WEB.bat`, `PREPARAR_WEB.ps1` e `INSTRUCOES_WEB_WINDOWS.md`. |

## Dependências

- Adicionada `sqflite_common_ffi_web: ^1.0.2` (compatível com Dart 3.9; versões 1.1+ exigem Dart mais novo).
- Adicionada `http: ^1.5.0` para as chamadas HTTP da implementação Web.
- Mantidas as demais dependências originais, sem atualização indiscriminada.

## Comandos Flutter e resultados

| Comando | Status |
| --- | --- |
| `flutter clean` | Não executado. Flutter indisponível no ambiente. |
| `flutter pub get` | Não executado. Flutter indisponível no ambiente. |
| `flutter analyze` | Não executado. Flutter indisponível no ambiente. |
| `flutter test` | Não executado. Flutter indisponível no ambiente. |
| `flutter build web` | Não executado. Flutter indisponível no ambiente. |
| `flutter run -d chrome` | Não executado. Chrome/Flutter indisponíveis no ambiente. |
| `dart run sqflite_common_ffi_web:setup` | Não executado. Dart indisponível; WASM e worker ainda devem ser gerados no Windows. |

A verificação estática via Python confirmou os nomes e destinos dos imports relativos usados pelo código, a validade de JSON/YAML, o conteúdo do ZIP e a ausência de imports nativos alcançáveis pelo `main.dart` no ramo Web. Ela **não equivale** a uma compilação Dart/Flutter.

## Limitações e pendências

- O projeto **não está validado em compilação ou execução real**. É necessário executar os comandos no Windows, resolver eventuais diagnósticos e realizar testes manuais.
- Os binários `web/sqlite3.wasm` e `web/sqflite_sw.js` **não estão neste ZIP**; o projeto inclui automatização para gerá-los usando o SDK e acesso à internet no Windows. Sem eles, a tela pode permanecer branca no primeiro acesso ao banco.
- O SQLite Web usa IndexedDB por origem, isolado do banco Windows. A porta Web deve ficar fixa (exemplo: `7357`) para evitar aparentes perdas de dados entre execuções.
- O armazenamento Web está sujeito a cota e à limpeza de dados do navegador. Não há migração automática de banco entre plataformas.
- O navegador não oferece sockets UDP/TCP de host nem descoberta por broadcast. A sincronização como **cliente** depende de desktop host atualizado, CORS e permissões de rede; precisa de teste real.
- Não foi inventado suporte a espanhol/japonês, ausente no ZIP original; português/inglês foram preservados.
- Os relatórios anteriores no projeto registram o estado **antes desta adaptação** e não substituem este relatório.

## Referências técnicas para validar no Windows

- https://pub.dev/packages/sqflite_common_ffi_web/versions/1.0.2
- https://pub.dev/packages/sqflite_common_ffi_web
- https://pub.dev/packages/sqflite

## Complemento: diagnóstico da tela branca (registro do PowerShell)

O log do usuário confirma que `flutter pub get` terminou, o `flutter analyze` retornou apenas três avisos informativos e `flutter run -d chrome` iniciou a conexão ao Chrome. O acesso ao banco falhou com a mensagem `An error occurred while initializing the web worker` e a ausência de `sqflite_sw.js`; verificou-se também a ausência de `sqlite3.wasm` no ZIP recebido.

Nesta revisão:
- `INICIAR_WEB.bat` prepara os binários no Windows, verifica existência e tamanho, e mantém a porta 7357 fixa.
- `lib/main.dart` mostra carregamento de inicialização e, caso a abertura do banco falhe, apresenta uma tela com o erro e o comando de setup em vez de deixar a tela branca.
- `database_factory_io.dart` teve removido um import redundante (sem alterar comportamento).
- O projeto será empacotado sem pastas temporárias como `.dart_tool/` e `build/`.

Limitação: não foi possível gerar os binários SQLite nem executar Flutter/Chrome neste ambiente. O preparo via script é obrigatório.
