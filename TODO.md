# TO-DO — Sysyphus Learning App

## BACK-END (FOCO ATUAL)

### Schemas
- [x] Criar tag_schema.dart
- [x] Criar session_schema.dart
- [x] Criar revlog_schema.dart (heavy log)
- [x] Criar question_schema.dart
- [x] Criar package_schema.dart
- [X] Revisar template_schema.dart

### Database
- [ ] Revisar DatabaseHelper
- [ ] Garantir criação de todas as tabelas
- [ ] Validar relacionamentos (FKs)
- [ ] Testar migrações / versionamento do banco

### DAOs
- [ ] Revisar package_dao.dart
- [ ] Revisar question_dao.dart
- [ ] Revisar revlog_dao.dart
- [ ] Revisar session_dao.dart
- [ ] Revisar tag_dao.dart
- [ ] Revisar template_dao.dart
- [ ] Revisar user_dao.dart

### User System (Refatoração)
- [X] Separar User em:
  - [x] profile (dados do usuário dentro do app)
  - [x] account (login / autenticação futura)
- [ ] Criar profile_schema.dart
- [ ] Criar account_schema.dart
- [ ] Ajustar DAOs para suportar essa separação
- [ ] Planejar relação account → múltiplos profiles

### Integração
- [ ] Conectar DAOs com a lógica do app
- [ ] Criar serviços intermediários (opcional, mas recomendado)
- [ ] Testar CRUD completo de cada entidade

---

## FRONT-END

### Telas existentes (ajustes)
- [ ] Ajustar tela de questões
- [ ] Refinar tela de estatísticas
- [ ] Revisar tela de configurações

### Telas faltantes
- [ ] Criar tela "About"
- [ ] Definir e implementar subcategorias em Configurações

---

## ORGANIZAÇÃO / ARQUITETURA

- [ ] Revisar estrutura de pastas (data / DAO / schema)
- [ ] Padronizar nomenclatura (_schema.dart)
- [ ] Garantir separação clara entre:
  - [ ] data
  - [ ] domain (se houver)
  - [ ] presentation

---

## TESTES

- [ ] Testar inserção de dados
- [ ] Testar queries (filtros por tag, pacote, etc.)
- [ ] Validar consistência entre entidades
- [ ] Testar edge cases (dados nulos, duplicados, etc.)

---

## FUTURO (NÃO PRIORITÁRIO AGORA)

- [ ] Sistema de autenticação (account)
- [ ] Sincronização de dados (cloud)
- [ ] Multi-profile por conta
- [ ] Backup / restore