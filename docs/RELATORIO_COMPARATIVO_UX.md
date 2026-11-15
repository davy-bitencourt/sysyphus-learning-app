# Análise comparativa de UX: Flashcards Brasil e Sysyphus Learning App

**Data:** 15/11/2026  
**Fontes analisadas:** `flashcards_brasil_v3_4(1).zip`, `sysyphus-learning-app-main(3).zip` e seis capturas de tela do Flashcards Brasil.

## 1. Síntese

A referência possui um fluxo curto para criar baralhos: o botão "Novo baralho" abre um `AlertDialog` com título e descrição, a criação atualiza o estado do aplicativo e o cartão oferece acesso imediato ao cadastro de flashcards. O editor da referência tem seleção de tipo (aberta, múltipla escolha e verdadeiro ou falso) e só mostra os controles necessários para cada modalidade. A lista inicial exibe cartões, contagens e botões de ação.

O Sysyphus original já havia recebido algumas melhorias: botão "Nova matéria" visível, busca de matérias, formulário de questão aberta com pergunta e resposta, opções avançadas recolhidas, cadastro consecutivo e ações nos cartões. No entanto, a criação de matéria ainda abria uma página inteira, a seleção dos tipos de questão dependia da compreensão dos modelos (templates), e as contagens por matéria não eram visíveis no cartão.

**Diferença arquitetural essencial:** o Flashcards Brasil usa `Deck` e `Flashcard` com tipo explícito. O Sysyphus usa `package`, `question` e `templates`; os campos de cada questão são armazenados em JSON na tabela `question`. Não seria correto copiar os modelos de dados do Flashcards Brasil.

## 2. Tabela comparativa

| Aspecto | Flashcards Brasil | Sysyphus enviado | Solução aplicada ao Sysyphus |
| --- | --- | --- | --- |
| Criar coleção | Janela modal com título e descrição | Tela de criação de matéria | Nova janela modal com apenas título obrigatório; descrição não incluída porque não existe no esquema atual da tabela `package` |
| Próxima etapa | Cartão da coleção com ação de criar flashcard | Criar matéria com opção de navegar ao editor | "Criar" ou "Criar e adicionar questão", criando de fato um registro SQLite |
| Criar questão | Tipo explícito antes dos campos | Modelo básico padrão; modelos personalizados dentro de opções avançadas | Seleção direta: aberta, múltipla escolha e verdadeiro ou falso; modelos personalizados continuam disponíveis |
| Formulário | Campos relevantes e comentário opcional | Pergunta e resposta no básico, extras conforme o template | Pergunta, resposta ou alternativas e comentário opcional; validações específicas |
| Cartão | Quantidade de flashcards e ações diretas | Título e ações | Quantidade de questões, adicionar, estudar, ver/editar e menu de edição/exclusão |
| Persistência | Repositórios próprios e estado do aplicativo | SQLite, DAOs e JSON de campos | Mantido o esquema do Sysyphus; apenas uso das DAOs existentes |
| Revisão | Mecanismo próprio | Sessões, estado e histórico de revisão | Não alterados; novas alternativas usam o formato gradável já suportado |
| Responsividade | Diálogos roláveis | Layout móvel/desktop baseado em plataforma | Layout da home baseado na largura; botões em coluna em espaços estreitos; diálogo rolável |

## 3. Priorização dos problemas

1. **Alta: início da criação de matéria demorado.** A abertura de uma página inteira para informar um único título aumenta o custo percebido. A criação rápida usa um diálogo com título obrigatório, cancelamento e ações explícitas.
2. **Alta: modalidade de questão pouco evidente.** Templates são um recurso poderoso, mas não deveriam ser condição para uma questão simples. Foi adicionado um seletor de tipo com três escolhas imediatas, preservando o acesso aos templates avançados.
3. **Alta: feedback e relação questão/matéria.** Os botões dos cartões levam diretamente ao editor predefinindo a matéria. Depois de salvar, os contadores são recalculados da base local.
4. **Média: campos excessivos para respostas de seleção.** Apenas as alternativas correspondentes ao tipo escolhido são exibidas. No tipo verdadeiro/falso, duas alternativas são preenchidas e o usuário escolhe uma correta.
5. **Média: acesso à exclusão e verificação de conteúdo.** Menu do cartão com edição e exclusão mediante confirmação. O botão "Ver e editar questões" mantém o acesso ao banco de questões.
6. **Média: telas menores e teclado virtual.** O formulário de matéria usa diálogo rolável. A home adapta botões à largura. O formulário de questão usa lista rolável e rodapé com cancelamento/salvamento.
7. **Acompanhar: internacionalização de telas antigas.** O pacote original tem apenas `pt.json` e `en.json`. A configuração foi estendida para `es` e `ja`, com traduções para todo o novo fluxo e fallback inglês nas mensagens antigas que não foram traduzidas.

## 4. Soluções e justificativa técnica

### Criação de matéria

O novo `lib/widgets/quick_subject_dialog.dart` valida o título e chama `PackageDao().insert(null, title)`. O id gerado permite abrir imediatamente `QuestionsEditScreen(packageId: id)`. A edição avançada continua disponível em `PackageEditScreen`. A descrição não foi adicionada artificialmente à tabela `package`, evitando migração desnecessária e alterações de sincronização/backup.

### Tipos de questão

O arquivo `lib/data/services/quick_question_templates.dart` registra apenas quando necessário dois presets no formato de `TemplateModel` existente. O tipo aberto utiliza o `SimpleQuestionTemplate` já existente. A múltipla escolha emprega `FieldType.options` com até quatro alternativas, exigindo ao menos duas preenchidas e uma única correta; as alternativas vazias não são gravadas. Verdadeiro/falso também emprega `FieldType.options` com duas escolhas, evitando reintroduzir o antigo `FieldType.vof` no editor.

As perguntas são armazenadas pela `QuestionDao.insert()`/`updateQuestion()`, e o campo opcional `ux_comment` é preservado no JSON da própria questão. O comentário aparece após a revelação da resposta na tela de estudo. Nenhuma versão do banco foi alterada.

### Manutenção

`PackageEditScreen` continua gerenciando título e sessão vinculada. `QuestionBankScreen` continua gerenciando a lista detalhada de questões. `QuestionScreen` mantém a avaliação de respostas e o histórico de revisão.

## 5. Arquivos diretamente criados ou modificados

| Arquivo | Alteração |
| --- | --- |
| `lib/widgets/quick_subject_dialog.dart` | Novo formulário modal persistente de matéria |
| `lib/screens/home.dart` | Criação rápida, contagens por matéria, ações de cartão, layout por largura |
| `lib/widgets/main_scaffold.dart` | Menu global "Nova matéria" usa o mesmo fluxo rápido |
| `lib/screens/questions_edit_screen.dart` | Tipos rápidos, alternativas, explicação opcional, validações, rodapé e criação de matéria vinculada |
| `lib/data/services/quick_question_templates.dart` | Presets compatíveis com os modelos de dados existentes |
| `lib/data/DAO/question_state_dao.dart` | Consulta agregada de contagem por matéria |
| `lib/screens/questions_screen.dart` | Exibição da explicação após resposta |
| `lib/l10n/strings.dart` | Seleção e carregamento de quatro idiomas; meses e dias locais |
| `lib/styles/app_theme.dart` | Idiomas espanhol e japonês nas configurações |
| `lib/l10n/pt.json`, `en.json`, `es.json`, `ja.json` | Novas traduções e catálogos adicionais |
| `test/quick_question_templates_test.dart` | Testes dos templates rápidos e compatibilidade JSON |
| `test/quick_subject_dialog_test.dart` | Teste de título obrigatório sem acesso ao banco |
| `test/ux_localization_test.dart` | Teste de presença das novas traduções |
| `tool/ux_static_check.py`, `tool/ux_sql_check.py` | Verificações locais que não dependem do SDK Flutter |

## 6. Limites e diferenças intencionais

* O Sysyphus **não** adota cores, nome, arquitetura ou componentes exclusivos do Flashcards Brasil.
* A descrição de matéria não foi implementada porque seria necessária a alteração da estrutura SQLite e dos formatos de transferência/sincronização. O fluxo rápido evita risco à integridade de dados existentes.
* Os novos modelos de múltipla escolha permitem **uma** opção correta. Templates personalizados existentes continuam podendo utilizar múltiplas respostas corretas.
* As novas traduções estão completas para o conjunto de chaves `ux.*` (em especial para os novos fluxos), mas os catálogos espanhol e japonês ainda usam fallback para inglês em **300 mensagens preexistentes**. Assim, a internacionalização global do aplicativo ainda não está concluída.
* Não foi possível medir quantitativamente o tempo ou número real de toques com participantes. As comparações refletem os fluxos e widgets dos códigos-fonte e as capturas anexadas, não um novo teste com usuários.

## 7. Próximas verificações recomendadas

Após instalar o Flutter, executar os comandos e o roteiro manual documentados em `docs/INSTRUCOES_EXECUCAO_UX.md`. Validar especialmente a recuperação de dados após reinicialização e a interface com teclado virtual e escala de texto ampliada. Os testes não executados não devem ser interpretados como aprovados.
