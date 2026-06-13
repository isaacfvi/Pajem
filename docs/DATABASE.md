# Pajem — Modelagem do Banco de Dados

> PostgreSQL. Convenções Rails (snake_case, bigserial PKs, timestamps automáticos).

---

## Diagrama de Relacionamentos

```
users
  ├── has_many :contexts
  ├── has_many :lists
  ├── has_many :items (through :lists)
  ├── has_many :audit_logs
  └── has_many :chat_messages

contexts
  ├── belongs_to :user
  └── has_many :lists (dependent: nullify)

lists
  ├── belongs_to :user
  ├── belongs_to :context (optional)
  └── has_many :items (dependent: destroy)

items
  ├── belongs_to :list
  └── belongs_to :user

audit_logs
  ├── belongs_to :user (optional)
  └── belongs_to :auditable (polymorphic) → List | Item | Context

chat_messages
  └── belongs_to :user
```

---

## Tabelas

### `users`

| Coluna                     | Tipo          | Restrições       | Descrição                                           |
|----------------------------|---------------|------------------|-----------------------------------------------------|
| `id`                       | bigserial     | PK               |                                                     |
| `name`                     | varchar(255)  | NOT NULL         |                                                     |
| `email`                    | varchar(255)  | NOT NULL, UNIQUE |                                                     |
| `password_digest`          | varchar(255)  | NOT NULL         | Hash bcrypt via `has_secure_password`               |
| `reset_password_token`     | varchar(255)  | UNIQUE, nullable | Token gerado para recuperação de senha              |
| `reset_password_sent_at`   | timestamp     | nullable         | Controle de expiração do token (ex: 2h)             |
| `deleted_at`               | timestamp     | nullable         | Soft delete — conta desativada mas dados preservados |
| `created_at`               | timestamp     | NOT NULL         |                                                     |
| `updated_at`               | timestamp     | NOT NULL         |                                                     |

---

### `contexts`

| Coluna       | Tipo         | Restrições                        | Descrição                              |
|--------------|--------------|-----------------------------------|----------------------------------------|
| `id`         | bigserial    | PK                                |                                        |
| `user_id`    | bigint       | NOT NULL, FK → users, ON DELETE CASCADE |                                  |
| `name`       | varchar(100) | NOT NULL                          | Ex: "Trabalho", "Estudos", "Casa"      |
| `created_at` | timestamp    | NOT NULL                          |                                        |
| `updated_at` | timestamp    | NOT NULL                          |                                        |

> **Restrição:** `UNIQUE(user_id, name)` — o mesmo usuário não pode ter dois contextos com o mesmo nome.

---

### `lists`

| Coluna          | Tipo         | Restrições                              | Descrição                                    |
|-----------------|--------------|-----------------------------------------|----------------------------------------------|
| `id`            | bigserial    | PK                                      |                                              |
| `user_id`       | bigint       | NOT NULL, FK → users, ON DELETE CASCADE |                                              |
| `context_id`    | bigint       | FK → contexts, ON DELETE SET NULL       | Nullable — lista sem contexto é válida       |
| `title`         | varchar(255) | NOT NULL                                |                                              |
| `description`   | text         | nullable                                |                                              |
| `color`         | varchar(7)   | nullable                                | Hex: `#A3B4C5`                               |
| `share_token`   | varchar(255) | UNIQUE, nullable                        | Gerado com `SecureRandom.urlsafe_base64`     |
| `share_enabled` | boolean      | NOT NULL, DEFAULT false                 | Ativa/desativa o link sem perder o token     |
| `deleted_at`    | timestamp    | nullable                                | Soft delete — nulo = ativo                   |
| `created_at`    | timestamp    | NOT NULL                                |                                              |
| `updated_at`    | timestamp    | NOT NULL                                |                                              |

---

### `items`

| Coluna         | Tipo         | Restrições                              | Descrição                                      |
|----------------|--------------|-----------------------------------------|------------------------------------------------|
| `id`           | bigserial    | PK                                      |                                                |
| `list_id`      | bigint       | NOT NULL, FK → lists, ON DELETE CASCADE |                                                |
| `user_id`      | bigint       | NOT NULL, FK → users, ON DELETE CASCADE | Desnormalizado para scoping direto no controller |
| `title`        | varchar(255) | NOT NULL                                |                                                |
| `description`  | text         | nullable                                |                                                |
| `completed`    | boolean      | NOT NULL, DEFAULT false                 |                                                |
| `completed_at` | timestamp    | nullable                                | Preenchido ao marcar como concluído            |
| `due_date`     | date         | nullable                                |                                                |
| `priority`     | integer      | nullable                                | Rails enum: `0` baixa, `1` média, `2` alta     |
| `deleted_at`   | timestamp    | nullable                                | Soft delete — nulo = ativo                     |
| `created_at`   | timestamp    | NOT NULL                                |                                                |
| `updated_at`   | timestamp    | NOT NULL                                |                                                |

---

### `audit_logs`

| Coluna           | Tipo        | Restrições                            | Descrição                                              |
|------------------|-------------|---------------------------------------|--------------------------------------------------------|
| `id`             | bigserial   | PK                                    |                                                        |
| `user_id`        | bigint      | FK → users, ON DELETE SET NULL        | Nullable — preserva o log mesmo se o usuário for deletado |
| `auditable_type` | varchar(50) | NOT NULL                              | `'List'`, `'Item'`, `'Context'`                        |
| `auditable_id`   | bigint      | NOT NULL                              | ID do registro auditado                                |
| `action`         | varchar(50) | NOT NULL                              | `created` `updated` `deleted` `restored` `completed` `uncompleted` `shared` `unshared` |
| `origin`         | varchar(20) | NOT NULL, DEFAULT `'manual'`          | `'manual'` ou `'assistant'`                            |
| `changes`        | jsonb       | nullable                              | `{"title": {"from": "antigo", "to": "novo"}}`          |
| `created_at`     | timestamp   | NOT NULL                              |                                                        |

> `audit_logs` não tem `updated_at` — registros de auditoria são imutáveis.

---

### `chat_messages`

| Coluna       | Tipo        | Restrições                              | Descrição                                                  |
|--------------|-------------|-----------------------------------------|------------------------------------------------------------|
| `id`         | bigserial   | PK                                      |                                                            |
| `user_id`    | bigint      | NOT NULL, FK → users, ON DELETE CASCADE |                                                            |
| `role`       | varchar(20) | NOT NULL                                | `'user'` ou `'assistant'`                                  |
| `content`    | text        | NOT NULL                                |                                                            |
| `metadata`   | jsonb       | nullable                                | Tool calls, erros, contexto extra do loop agêntico         |
| `created_at` | timestamp   | NOT NULL                                |                                                            |

> `chat_messages` não tem `updated_at` — mensagens são imutáveis após criação.

---

## Índices

```sql
-- users
CREATE UNIQUE INDEX idx_users_email ON users(email);
CREATE UNIQUE INDEX idx_users_reset_password_token ON users(reset_password_token) WHERE reset_password_token IS NOT NULL;
CREATE INDEX idx_users_deleted_at ON users(deleted_at);

-- contexts
CREATE INDEX idx_contexts_user_id ON contexts(user_id);
CREATE UNIQUE INDEX idx_contexts_user_name ON contexts(user_id, name);

-- lists
CREATE INDEX idx_lists_user_id ON lists(user_id);
CREATE INDEX idx_lists_context_id ON lists(context_id);
CREATE INDEX idx_lists_deleted_at ON lists(deleted_at);
CREATE UNIQUE INDEX idx_lists_share_token ON lists(share_token) WHERE share_token IS NOT NULL;

-- items
CREATE INDEX idx_items_list_id ON items(list_id);
CREATE INDEX idx_items_user_id ON items(user_id);
CREATE INDEX idx_items_deleted_at ON items(deleted_at);
CREATE INDEX idx_items_list_active ON items(list_id, deleted_at);
CREATE INDEX idx_items_list_priority ON items(list_id, priority) WHERE deleted_at IS NULL;
CREATE INDEX idx_items_overdue_active ON items(user_id, due_date) WHERE due_date IS NOT NULL AND deleted_at IS NULL AND completed = false;

-- audit_logs
CREATE INDEX idx_audit_logs_user_recent ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_auditable ON audit_logs(auditable_type, auditable_id);

-- chat_messages
CREATE INDEX idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at);

-- busca por texto (requer extensão pg_trgm)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_lists_title_trgm ON lists USING gin (title gin_trgm_ops);
CREATE INDEX idx_items_title_trgm ON items USING gin (title gin_trgm_ops);
```

> Índices trigram não são expressáveis pelo helper `add_index` do Rails — usar `execute` na migration e configurar `config.active_record.schema_format = :sql` no `application.rb`.

---

## Decisões de Design

| Decisão | Motivo |
|---|---|
| `deleted_at` em `users` | Soft delete de conta — preserva listas e itens do usuário, apenas desativa o acesso (F-17) |
| `reset_password_token` + `reset_password_sent_at` | Controle manual de recuperação de senha sem Devise — token expira por tempo, índice parcial evita indexar nulls |
| `user_id` em `items` (desnormalizado) | Permite `current_user.items.find(id)` sem join com `lists` — scoping direto e mais seguro nos controllers |
| `jsonb` em `audit_logs.changes` e `chat_messages.metadata` | Tipo nativo do PostgreSQL, indexável, flexível para estruturas variáveis |
| `share_enabled` separado de `share_token` | Permite desativar o link temporariamente sem perder o token gerado |
| `completed_at` além de `completed` | Permite saber exatamente quando foi concluído — útil para o dashboard e auditoria |
| `ON DELETE SET NULL` em `context_id` | Exclusão de contexto não arrasta as listas — elas ficam sem contexto |
| `ON DELETE SET NULL` em `audit_logs.user_id` | Preserva histórico de auditoria mesmo após exclusão do usuário (compliance) |
| Índice parcial em `share_token` | `WHERE share_token IS NOT NULL` — não indexa nulls, menor e mais eficiente |
| Índice composto `(list_id, deleted_at)` em items | Query mais comum: buscar itens ativos de uma lista específica |
| Índice composto `(user_id, created_at DESC)` em audit_logs | Substitui dois índices separados — cobre a query de "atividade recente do usuário" do dashboard com index-only scan |
| Índice parcial `(list_id, priority)` em items | Filtragem e ordenação por prioridade apenas em itens ativos (F-07/F-09) |
| Índice parcial `(user_id, due_date)` em items | Cobre a query de itens vencidos/próximos do dashboard — filtra `deleted_at IS NULL AND completed = false` no próprio índice |
| Índices GIN trigram em `lists.title` e `items.title` | Suporte a busca por substring (`ILIKE '%termo%'`) com performance aceitável (F-09) — requer `pg_trgm` e `schema_format = :sql` |
