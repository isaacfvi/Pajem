# Pajem

Aplicação web de gerenciamento de tarefas com assistente de IA integrado. O Pajem interpreta comandos em linguagem natural e executa ações diretamente — cria listas, adiciona itens, marca tarefas como concluídas — sem que o usuário precise navegar pela interface.

## Stack

- **Ruby 3.4.9 / Rails 8.1** — monolito com Hotwire (Turbo + Stimulus)
- **PostgreSQL 16** — busca por trigram via extensão `pg_trgm`; cache, fila e Action Cable via `solid_cache`, `solid_queue` e `solid_cable` (sem Redis)
- **bcrypt + `has_secure_password`** 
- **`discard`** — soft delete sem `default_scope` global
- **Groq API** — LLM `llama-3.3-70b-versatile` via `Net::HTTP` (sem gem extra)

## Funcionalidades

- Cadastro, login e recuperação de senha por e-mail
- Organização de listas por **contextos** (ex.: Trabalho, Pessoal)
- Itens com prioridade (`low`, `medium`, `high`) e data de vencimento
- **Updates em tempo real** — criação, edição e conclusão de listas e itens via Turbo Stream sem reload
- **Compartilhamento de listas** via link público com token
- **Lixeira** com restore e exclusão permanente
- **Histórico de auditoria** de todas as ações (origem: `manual` ou `assistant`)
- **Dashboard** com gráficos de atividade (Chartkick + Groupdate)
- **Assistente Pajem** — pipeline em 3 etapas: Guardrails → loop agêntico (máx. 6 iterações) → Responder

### Pipeline do assistente

```
mensagem do usuário
  └─ Guardrails    — filtra mensagens fora do escopo (trivia, cálculos, ofensas)
       └─ Assistant — loop agêntico: chama tools até concluir a tarefa (máx. 6 iterações)
            └─ Responder — gera resposta em linguagem natural com base nas ações executadas
```

### Tools do assistente

| Tool | Descrição |
|---|---|
| `list_contexts` | Lista todos os contextos |
| `list_lists` | Lista as listas ativas |
| `list_items` | Lista os itens de uma lista |
| `create_context` | Cria um novo contexto |
| `create_list` | Cria uma nova lista |
| `create_item` | Cria um item com título, prioridade e data |
| `set_context` | Associa uma lista a um contexto |
| `complete_item` | Marca um item como concluído |
| `uncomplete_item` | Remove a marcação de concluído |
| `delete_list` | Move uma lista para a lixeira |
| `delete_item` | Move um item para a lixeira |

## Pré-requisitos

- Ruby 3.4.9
- Docker e Docker Compose (para o PostgreSQL)
- Conta na [Groq](https://console.groq.com) para obter a chave de API do assistente

## Configuração

### 1. Variáveis de ambiente

```bash
cp .env.example .env
```

Edite o `.env` com suas credenciais:

```env
POSTGRES_USER=pajem
POSTGRES_PASSWORD=secret
POSTGRES_DB=pajem_development

DATABASE_URL=postgres://pajem:secret@localhost:5432/pajem_development
TEST_DATABASE_URL=postgres://pajem:secret@localhost:5432/pajem_test

# SMTP para recuperação de senha (ex.: Mailtrap)
SMTP_HOST=smtp.mailtrap.io
SMTP_PORT=587
SMTP_USERNAME=seu_usuario
SMTP_PASSWORD=sua_senha
MAILER_FROM=Pajem <noreply@pajem.app>

# Groq — assistente de IA
GROQ_API_KEY=sua_chave_aqui
```

### 2. Banco de dados

```bash
docker compose up -d
bundle install
bin/rails db:create db:migrate
```

### 3. Servidor

```bash
bin/rails server
```

Acesse em `http://localhost:3000`.

## Testes

```bash
bin/rails test
bin/rails test:system
```

O CI roda em PostgreSQL 16 via GitHub Actions e inclui testes unitários, de controller, de serviços do assistente e testes de sistema com Selenium.

## CI

O pipeline no GitHub Actions executa a cada push em `main` e em pull requests:

| Job | O que faz |
|---|---|
| `scan_ruby` | Brakeman (análise estática) + bundler-audit (CVEs em gems) |
| `scan_js` | `importmap audit` (CVEs em dependências JS) |
| `lint` | RuboCop com cache |
| `test` | Suite completa de testes unitários e de integração |
| `system-test` | Testes de sistema com Selenium (screenshots em falhas) |

## Estrutura

```
app/
├── assets/
│   └── stylesheets/
│       ├── application.css
│       └── layout/
│           ├── accounts.css
│           ├── audit_log.css
│           ├── content.css
│           ├── dashboard.css
│           ├── filter.css
│           ├── pajem_widget.css
│           ├── postit.css
│           ├── share.css
│           ├── sidebar.css
│           ├── topbar.css
│           └── trash.css
├── controllers/
│   ├── application_controller.rb
│   ├── accounts_controller.rb
│   ├── audit_logs_controller.rb
│   ├── contexts_controller.rb
│   ├── dashboard_controller.rb
│   ├── home_controller.rb
│   ├── items_controller.rb
│   ├── lists_controller.rb
│   ├── password_resets_controller.rb
│   ├── registrations_controller.rb
│   ├── sessions_controller.rb
│   ├── shares_controller.rb
│   ├── trash_controller.rb
│   └── pajem/
│       └── messages_controller.rb
├── javascript/
│   ├── application.js
│   └── controllers/
│       ├── clipboard_controller.js
│       ├── color_picker_controller.js
│       ├── context_delete_controller.js
│       ├── flash_controller.js
│       ├── inline_context_controller.js
│       ├── item_toggle_controller.js
│       ├── list_expand_controller.js
│       ├── pajem_chat_controller.js
│       └── theme_controller.js
├── mailers/
│   ├── application_mailer.rb
│   └── user_mailer.rb
├── models/
│   ├── application_record.rb
│   ├── audit_log.rb
│   ├── chat_message.rb
│   ├── context.rb
│   ├── item.rb
│   ├── list.rb
│   ├── user.rb
│   └── concerns/
│       ├── auditable.rb
│       └── soft_deletable.rb
├── services/
│   └── pajem/
│       ├── assistant.rb
│       ├── errors.rb
│       ├── guardrails.rb
│       ├── llm_client.rb
│       ├── responder.rb
│       ├── tool_definitions.rb
│       ├── tools.rb
│       └── providers/
│           └── groq.rb
└── views/
    ├── accounts/
    │   ├── reactivation_form.html.erb
    │   └── show.html.erb
    ├── audit_logs/
    │   └── index.html.erb
    ├── contexts/
    │   ├── _context_item.html.erb
    │   ├── _form.html.erb
    │   ├── edit.html.erb
    │   └── new.html.erb
    ├── dashboard/
    │   └── index.html.erb
    ├── home/
    │   └── index.html.erb
    ├── items/
    │   ├── _item.html.erb
    │   ├── _new_form.html.erb
    │   ├── create.turbo_stream.erb
    │   ├── destroy.turbo_stream.erb
    │   ├── edit.html.erb
    │   ├── index.html.erb
    │   ├── show.html.erb
    │   ├── toggle.turbo_stream.erb
    │   └── update.turbo_stream.erb
    ├── layouts/
    │   ├── application.html.erb
    │   ├── mailer.html.erb
    │   ├── mailer.text.erb
    │   └── share.html.erb
    ├── lists/
    │   ├── _expanded_panel.html.erb
    │   ├── _form.html.erb
    │   ├── _postit_card.html.erb
    │   ├── _progress_bar.html.erb
    │   ├── _share_panel.html.erb
    │   ├── compartilhar.turbo_stream.erb
    │   ├── edit.html.erb
    │   ├── index.html.erb
    │   ├── new.html.erb
    │   └── revogar_link.turbo_stream.erb
    ├── pajem/messages/
    │   └── create.turbo_stream.erb
    ├── password_resets/
    │   ├── edit.html.erb
    │   └── new.html.erb
    ├── pwa/
    │   ├── manifest.json.erb
    │   └── service-worker.js
    ├── registrations/
    │   └── new.html.erb
    ├── sessions/
    │   └── new.html.erb
    ├── shared/
    │   ├── _flash.html.erb
    │   ├── _sidebar.html.erb
    │   └── _topbar.html.erb
    ├── shares/
    │   └── show.html.erb
    ├── trash/
    │   └── index.html.erb
    └── user_mailer/
        ├── account_reactivation.html.erb
        ├── account_reactivation.text.erb
        ├── password_reset.html.erb
        └── password_reset.text.erb

config/
├── environments/
│   ├── development.rb
│   ├── production.rb
│   └── test.rb
├── initializers/
│   ├── assets.rb
│   ├── content_security_policy.rb
│   ├── filter_parameter_logging.rb
│   └── inflections.rb
├── locales/
│   └── en.yml
├── application.rb
├── cable.yml
├── cache.yml
├── database.yml
├── deploy.yml
├── importmap.rb
├── puma.rb
├── queue.yml
├── recurring.yml
├── routes.rb
└── storage.yml

db/
├── migrate/
│   ├── 20260613000001_enable_pg_trgm.rb
│   ├── 20260613000002_create_users.rb
│   ├── 20260613000003_create_contexts.rb
│   ├── 20260613000004_create_lists.rb
│   ├── 20260613000005_create_items.rb
│   ├── 20260613000006_create_audit_logs.rb
│   ├── 20260613000007_create_chat_messages.rb
│   └── 20260613000008_rename_changes_to_changeset_in_audit_logs.rb
├── cable_schema.rb
├── cache_schema.rb
├── queue_schema.rb
├── seeds.rb
└── structure.sql

test/
├── controllers/
│   ├── accounts_controller_test.rb
│   ├── audit_logs_controller_test.rb
│   ├── contexts_controller_test.rb
│   ├── dashboard_controller_test.rb
│   ├── items_controller_test.rb
│   ├── lists_controller_test.rb
│   ├── password_resets_controller_test.rb
│   ├── registrations_controller_test.rb
│   ├── sessions_controller_test.rb
│   ├── shares_controller_test.rb
│   ├── trash_controller_test.rb
│   └── pajem/
│       └── messages_controller_test.rb
├── models/
│   ├── audit_log_test.rb
│   ├── chat_message_test.rb
│   ├── context_test.rb
│   ├── item_test.rb
│   ├── list_test.rb
│   └── user_test.rb
├── services/
│   └── pajem/
│       ├── assistant_test.rb
│       ├── guardrails_test.rb
│       └── tools_test.rb
├── application_system_test_case.rb
└── test_helper.rb
```

## Deploy

O projeto inclui configuração para deploy via **Kamal** (`config/deploy.yml`). Ajuste o arquivo com o endereço do servidor e as credenciais antes de usar.
