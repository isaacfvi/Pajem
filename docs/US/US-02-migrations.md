# US-02 — Migrations

**Task de origem:** T-02  
**Depende de:** US-01 (T-01)  
**Features relacionadas:** todas (fundação do banco de dados)

---

## Contexto

Com o projeto Rails inicializado e o PostgreSQL rodando via Docker, a próxima etapa é criar o schema completo do banco de dados. Todas as migrações devem ser escritas na ordem correta respeitando as foreign keys, incluir os índices necessários para performance, ativar a extensão `pg_trgm` e criar os índices GIN para busca por texto. O resultado final deve ser um banco de dados íntegro, pronto para receber os models e a lógica da aplicação.

---

## User Stories

**Como** desenvolvedor do projeto,  
**Quero** ter todas as tabelas e índices criados no banco via migrations Rails,  
**Para que** os models possam ser implementados sem alterar o schema depois.

---

## Critérios de Aceitação

### 1. Extensão `pg_trgm` ativada

- [x] Migration inicial ativa a extensão com `enable_extension "pg_trgm"`
- [x] Executada antes de qualquer migration que use índices GIN trigram

### 2. Migration `create_users`

- [x] Tabela criada com as colunas: `name`, `email`, `password_digest`, `reset_password_token`, `reset_password_sent_at`, `deleted_at`, `timestamps`
- [x] `email`: `null: false`, `limit: 255`
- [x] `name`: `null: false`, `limit: 255`
- [x] `password_digest`: `null: false`, `limit: 255`
- [x] `reset_password_token`: nullable, `limit: 255`
- [x] `reset_password_sent_at`: nullable, timestamp
- [x] `deleted_at`: nullable, timestamp
- [x] Índices criados:
  - [x] `UNIQUE` em `email`
  - [x] `UNIQUE` parcial em `reset_password_token` (`WHERE reset_password_token IS NOT NULL`)
  - [x] Simples em `deleted_at`

### 3. Migration `create_contexts`

- [x] Tabela criada com as colunas: `user_id`, `name`, `timestamps`
- [x] `user_id`: `null: false`, FK → `users`, `ON DELETE CASCADE`
- [x] `name`: `null: false`, `limit: 100`
- [x] Índices criados:
  - [x] Simples em `user_id`
  - [x] `UNIQUE` composto em `(user_id, name)`

### 4. Migration `create_lists`

- [x] Tabela criada com as colunas: `user_id`, `context_id`, `title`, `description`, `color`, `share_token`, `share_enabled`, `deleted_at`, `timestamps`
- [x] `user_id`: `null: false`, FK → `users`, `ON DELETE CASCADE`
- [x] `context_id`: nullable, FK → `contexts`, `ON DELETE SET NULL`
- [x] `title`: `null: false`, `limit: 255`
- [x] `description`: nullable, `text`
- [x] `color`: nullable, `limit: 7` (hex `#RRGGBB`)
- [x] `share_token`: nullable, `limit: 255`
- [x] `share_enabled`: `null: false`, `default: false`, boolean
- [x] `deleted_at`: nullable, timestamp
- [x] Índices criados:
  - [x] Simples em `user_id`
  - [x] Simples em `context_id`
  - [x] Simples em `deleted_at`
  - [x] `UNIQUE` parcial em `share_token` (`WHERE share_token IS NOT NULL`)
  - [x] GIN trigram em `title` via `execute`

### 5. Migration `create_items`

- [x] Tabela criada com as colunas: `list_id`, `user_id`, `title`, `description`, `completed`, `completed_at`, `due_date`, `priority`, `deleted_at`, `timestamps`
- [x] `list_id`: `null: false`, FK → `lists`, `ON DELETE CASCADE`
- [x] `user_id`: `null: false`, FK → `users`, `ON DELETE CASCADE`
- [x] `title`: `null: false`, `limit: 255`
- [x] `description`: nullable, `text`
- [x] `completed`: `null: false`, `default: false`, boolean
- [x] `completed_at`: nullable, timestamp
- [x] `due_date`: nullable, `date`
- [x] `priority`: nullable, `integer` (enum Rails: `0` baixa, `1` média, `2` alta)
- [x] `deleted_at`: nullable, timestamp
- [x] Índices criados:
  - [x] Simples em `list_id`
  - [x] Simples em `user_id`
  - [x] Simples em `deleted_at`
  - [x] Composto em `(list_id, deleted_at)`
  - [x] Composto parcial em `(list_id, priority)` (`WHERE deleted_at IS NULL`)
  - [x] Composto parcial em `(user_id, due_date)` (`WHERE due_date IS NOT NULL AND deleted_at IS NULL AND completed = false`)
  - [x] GIN trigram em `title` via `execute`

### 6. Migration `create_audit_logs`

- [x] Tabela criada **sem** `updated_at` (registros imutáveis — apenas `created_at`)
- [x] Colunas: `user_id`, `auditable_type`, `auditable_id`, `action`, `origin`, `changes`, `created_at`
- [x] `user_id`: nullable, FK → `users`, `ON DELETE SET NULL`
- [x] `auditable_type`: `null: false`, `limit: 50`
- [x] `auditable_id`: `null: false`, bigint
- [x] `action`: `null: false`, `limit: 50`
- [x] `origin`: `null: false`, `limit: 20`, `default: "manual"`
- [x] `changes`: nullable, `jsonb`
- [x] Índices criados:
  - [x] Composto em `(user_id, created_at DESC)` — cobre a query de atividade recente do dashboard
  - [x] Composto em `(auditable_type, auditable_id)`

### 7. Migration `create_chat_messages`

- [x] Tabela criada **sem** `updated_at` (mensagens imutáveis — apenas `created_at`)
- [x] Colunas: `user_id`, `role`, `content`, `metadata`, `created_at`
- [x] `user_id`: `null: false`, FK → `users`, `ON DELETE CASCADE`
- [x] `role`: `null: false`, `limit: 20`
- [x] `content`: `null: false`, `text`
- [x] `metadata`: nullable, `jsonb`
- [x] Índices criados:
  - [x] Simples em `user_id`
  - [x] Simples em `created_at`

### 8. `rails db:migrate` executa sem erros

- [x] Todas as migrations aplicadas em ordem sem exceção
- [x] `db/structure.sql` gerado e atualizado (reflexo do `schema_format = :sql`)
- [x] `rails db:migrate` no ambiente `test` também executa sem erros

---

## Notas Técnicas

**Ordem das migrations**  
A ordem de criação respeita as foreign keys: `users` → `contexts` → `lists` → `items` → `audit_logs` → `chat_messages`. Migrations fora de ordem causariam `PG::UndefinedTable` ao tentar referenciar uma tabela inexistente.

**Índices parciais e compostos via `execute`**  
O helper `add_index` do Rails não suporta a cláusula `WHERE` para índices parciais nem `USING gin`. Para esses casos, usar `execute` diretamente na migration:

```ruby
execute <<~SQL
  CREATE UNIQUE INDEX idx_users_reset_password_token
    ON users(reset_password_token)
    WHERE reset_password_token IS NOT NULL;

  CREATE INDEX idx_lists_title_trgm
    ON lists USING gin (title gin_trgm_ops);

  CREATE INDEX idx_items_list_priority
    ON items(list_id, priority)
    WHERE deleted_at IS NULL;

  CREATE INDEX idx_items_overdue_active
    ON items(user_id, due_date)
    WHERE due_date IS NOT NULL AND deleted_at IS NULL AND completed = false;
SQL
```

**`audit_logs` e `chat_messages` sem `updated_at`**  
Usar `t.timestamps null: false` criaria ambas as colunas. Para omitir `updated_at`, usar `t.datetime :created_at, null: false` diretamente e nunca chamar `t.timestamps`.

**`jsonb` para `changes` e `metadata`**  
Tipo nativo do PostgreSQL — armazenado em binário, indexável e mais performático que `json`. O Rails mapeia automaticamente para `Hash` no Ruby.

**`ON DELETE SET NULL` vs `ON DELETE CASCADE`**  
- `contexts → lists` usa `SET NULL`: excluir um contexto não destrói suas listas, apenas desassocia (`context_id` vai a `null`)
- `audit_logs → users` usa `SET NULL`: preserva o histórico mesmo após exclusão do usuário (compliance)
- Demais relações usam `CASCADE`: excluir um usuário remove seus dados em cascata

**Índice composto `(user_id, created_at DESC)` em `audit_logs`**  
Substitui dois índices separados em `user_id` e `created_at`. Cobre a query `WHERE user_id = ? ORDER BY created_at DESC LIMIT ?` com index-only scan — usada na página de atividade recente do dashboard (T-13).

---

## Definition of Done

- [x] Todas as migrations criadas e aplicadas sem erros em `development` e `test`
- [ ] `db/structure.sql` atualizado e commitado
- [ ] `rails db:schema:load` reconstrói o banco a partir do `structure.sql` sem erros
- [x] Extensão `pg_trgm` presente no `structure.sql`
- [x] Todos os índices (incluindo parciais e GIN) presentes no `structure.sql`
- [ ] `bundle exec rails test` roda (ambiente de test íntegro)
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
