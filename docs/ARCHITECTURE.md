# Pajem — Documento de Arquitetura

> Descreve como o software é organizado, como as peças se comunicam e as decisões estruturais que guiam a implementação.

---

## Visão Geral

O Pajem é uma aplicação web monolítica construída em **Ruby on Rails**, seguindo o padrão **MVC** com extensões de serviços para lógica de negócio complexa. Não há API separada nem frontend desacoplado — o servidor renderiza HTML e o **Hotwire** (Turbo + Stimulus) entrega a interatividade sem a necessidade de um framework JavaScript.

```
Browser ──HTTP──▶ Rails Router ──▶ Controller ──▶ Model / Service ──▶ PostgreSQL
         ◀──HTML──                 ◀──View (ERB)──
```

---

## Stack

| Camada         | Tecnologia                                      | Motivo                                          |
|----------------|-------------------------------------------------|-------------------------------------------------|
| Backend        | Ruby on Rails 7.x                               | Produtividade, convenções maduras               |
| Banco de dados | PostgreSQL                                      | JSONB, trigram search, robustez                 |
| Frontend       | Hotwire (Turbo Drive + Turbo Frames + Turbo Streams + Stimulus) | Interatividade sem SPA |
| Estilização    | CSS custom properties                           | Dark mode nativo sem dependência externa        |
| IA / Assistente| LLM API com tool use (Claude ou OpenAI)         | Loop agêntico com ferramentas                   |
| Autenticação   | `has_secure_password` (bcrypt) — sem Devise     | Controle total, sem overhead de gem pesada      |
| Soft Delete    | Gem `discard`                                   | Sem `default_scope` global, mais previsível     |

---

## Estrutura de Diretórios

```
app/
├── controllers/
│   ├── application_controller.rb       # autenticação base, current_user
│   ├── sessions_controller.rb          # login / logout
│   ├── registrations_controller.rb     # cadastro
│   ├── passwords_controller.rb         # recuperação de senha
│   ├── accounts_controller.rb          # desativação / hard delete de conta
│   ├── dashboard_controller.rb
│   ├── lists_controller.rb
│   ├── items_controller.rb
│   ├── contexts_controller.rb
│   ├── trash_controller.rb             # lixeira (soft deleted records)
│   ├── shares_controller.rb            # view pública via share_token (sem auth)
│   ├── audit_logs_controller.rb
│   └── pajem_controller.rb             # endpoint do assistente IA
│
├── models/
│   ├── user.rb
│   ├── list.rb
│   ├── item.rb
│   ├── context.rb
│   ├── audit_log.rb
│   └── chat_message.rb
│
├── services/
│   └── pajem/
│       ├── assistant.rb                # orquestra o loop agêntico
│       ├── tools.rb                    # implementação de cada tool em Ruby
│       └── tool_definitions.rb         # schemas JSON enviados à API
│
├── concerns/
│   ├── auditable.rb                    # concern compartilhado por List, Item, Context
│   └── soft_deletable.rb              # wrapper do discard com comportamentos comuns
│
└── views/
    ├── layouts/application.html.erb
    ├── dashboard/
    ├── lists/
    ├── items/
    ├── contexts/
    ├── trash/
    ├── audit_logs/
    ├── shares/                         # templates públicos (sem navbar autenticada)
    └── pajem/
```

---

## Arquitetura de Autenticação

Autenticação própria, sem Devise. Baseada em sessão do Rails.

```
POST /login
  └─▶ SessionsController#create
        └─▶ User.find_by(email).authenticate(password)   # bcrypt
              ├─ OK  → session[:user_id] = user.id → redirect
              └─ FAIL → render login com erro
```

**`ApplicationController`** expõe `current_user` e `require_auth`:

```ruby
def current_user
  @current_user ||= User.kept.find_by(id: session[:user_id])
end

def require_auth
  redirect_to login_path unless current_user
end
```

> `User.kept` é o scope do `discard` — contas desativadas (`deleted_at` preenchido) são tratadas como inexistentes para fins de login.

**Recuperação de senha:**
```
POST /passwords        → gera reset_password_token, envia e-mail
GET  /passwords/:token → valida token + expiração (reset_password_sent_at < 2.hours.ago)
PATCH /passwords/:token → atualiza password_digest, zera token
```

---

## Arquitetura do Assistente Pajem

O diferencial da aplicação. Implementado como um serviço Ruby que orquestra um **loop agêntico** com a API de LLM.

### Fluxo completo

```
[1] Usuário digita mensagem no chat
        │
        ▼
[2] POST /pajem
    PajemController#create
        │  salva ChatMessage (role: user)
        │
        ▼
[3] Pajem::Assistant.call(user: current_user)
        │  monta histórico: ChatMessage.where(user:).order(:created_at)
        │  adiciona system prompt
        │
        ▼
[4] Chamada à API do LLM (com tool definitions)
        │
        ├─ Resposta: texto puro
        │     └─▶ salva ChatMessage (role: assistant)
        │         retorna resposta via Turbo Stream → fim
        │
        └─ Resposta: tool_use
              │
              ▼
[5] Pajem::Tools.dispatch(tool_name, params, user:)
              │
              ├─ Ação não-destrutiva → executa → salva resultado
              │
              └─ Ação destrutiva (delete_*)
                    └─▶ retorna tool_result com status: "awaiting_confirmation"
                        salva mensagem de confirmação no chat
                        UI exibe botão Confirmar / Cancelar
                              │
                        Usuário confirma → POST /pajem com confirmation: true
                              └─▶ Tool executada, loop continua
              │
              ▼
[6] tool_result enviado de volta à API → volta para [4]
    (loop continua até resposta final em texto)
```

### Pajem::Assistant

```ruby
# app/services/pajem/assistant.rb
class Pajem::Assistant
  def initialize(user)
    @user = user
  end

  def call(user_message, confirmed_tool: nil, confirmed_params: nil)
    save_message(role: "user", content: user_message) if user_message.present?
    run_loop(confirmed_tool:, confirmed_params:)
  end

  private

  def run_loop(confirmed_tool: nil, confirmed_params: nil)
    # Se chega com confirmação pendente, executa a tool direto sem nova chamada à API
    if confirmed_tool
      result = Pajem::Tools.dispatch(confirmed_tool, confirmed_params, user: @user, confirmed: true)
      save_tool_result(result)
    end

    loop do
      response = api_client.chat(
        messages: build_messages,
        tools: Pajem::ToolDefinitions.all,
        system: system_prompt
      )

      if response.tool_use?
        result = Pajem::Tools.dispatch(response.tool_name, response.tool_params, user: @user)
        # metadata persiste tool_name + params para o ciclo de confirmação
        save_tool_result(result, metadata: { tool_name: response.tool_name, tool_params: response.tool_params })
        break if result[:awaiting_confirmation]
      else
        save_message(role: "assistant", content: response.text)
        break
      end
    end
  end

  def save_message(role:, content:, metadata: nil)
    @user.chat_messages.create!(role:, content:, metadata:)
  end
end
```

**Fluxo de confirmação detalhado:**

Quando o Pajem retorna `awaiting_confirmation`, a última `ChatMessage` salva com `role: "assistant"` carrega no campo `metadata` o `tool_name` e `tool_params` da ação pendente. A UI exibe os botões Confirmar/Cancelar. Ao confirmar:

```
POST /pajem  { confirmation: true }
  └─▶ PajemController#create
        └─▶ pending = current_user.chat_messages
                        .where(role: "assistant")
                        .order(created_at: :desc)
                        .first
            confirmed_tool   = pending.metadata["tool_name"]
            confirmed_params = pending.metadata["tool_params"]
            Pajem::Assistant.new(current_user)
              .call(nil, confirmed_tool:, confirmed_params:)
```


### Pajem::Tools

Cada tool é um método Ruby isolado que opera exclusivamente sobre `current_user`:

```ruby
# app/services/pajem/tools.rb
module Pajem::Tools
  def self.dispatch(name, params, user:)
    case name
    when "create_list"    then create_list(params, user:)
    when "delete_list"    then delete_list(params, user:)
    # ...
    end
  end

  def self.create_list(params, user:)
    list = user.lists.create!(params.slice(:title, :description, :color, :context_id))
    AuditLog.record(user:, record: list, action: :created, origin: :assistant)
    { success: true, list: list.as_json }
  end

  def self.delete_list(params, user:, confirmed: false)
    list = user.lists.kept.find(params[:list_id])
    return { awaiting_confirmation: true, message: "Deseja excluir a lista '#{list.title}'?" } unless confirmed
    list.discard
    AuditLog.record(user:, record: list, action: :deleted, origin: :assistant)
    { success: true }
  end
end
```

### System Prompt

O Pajem recebe um system prompt que define:
- Identidade: assistente medieval leal ao usuário
- Escopo: operar **apenas** sobre dados do usuário autenticado
- Regra de confirmação: ações destrutivas exigem confirmação explícita
- Capacidades: lista de tools disponíveis e quando usá-las

---

## Arquitetura de Soft Delete

Implementado com a gem **`discard`** (preferível ao `paranoia` por não usar `default_scope` global).

**Concern compartilhado:**

```ruby
# app/concerns/soft_deletable.rb
module SoftDeletable
  extend ActiveSupport::Concern
  included { include Discard::Model }
end
```

**Scopes disponíveis após include:**
- `Model.kept`       → registros ativos (`deleted_at IS NULL`)
- `Model.discarded`  → registros deletados (`deleted_at IS NOT NULL`)
- `Model.with_discarded` → todos

**Regra de cascata:**
- `List` deletada → itens NÃO são deletados em cascata pelo banco; o controller/service faz `list.items.discard_all` explicitamente
- `Context` deletado → `lists.context_id` vira `NULL` (via `ON DELETE SET NULL` no banco)
- `User` desativado → dados preservados; `User.kept` no `current_user` impede o login

---

## Arquitetura de Busca e Filtros (F-09)

Busca por substring em títulos de listas e itens é feita via **trigram similarity** do PostgreSQL, sem Elasticsearch ou gem extra.

**Dependência:** extensão `pg_trgm` (ativada via migration com `execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"`).

**Índices GIN** nos campos de busca (não expressáveis com `add_index` — requerem `execute` na migration):
```sql
CREATE INDEX idx_lists_title_trgm ON lists  USING gin (title gin_trgm_ops);
CREATE INDEX idx_items_title_trgm ON items  USING gin (title gin_trgm_ops);
```

**Configuração obrigatória** em `config/application.rb` para que o `schema.rb` gerado pelo Rails preserve os índices GIN:
```ruby
config.active_record.schema_format = :sql  # gera structure.sql em vez de schema.rb
```

**Uso nos controllers:**
```ruby
# ListsController
scope = current_user.lists.kept
scope = scope.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?
scope = scope.where(context_id: params[:context_id])    if params[:context_id].present?

# ItemsController
scope = @list.items.kept
scope = scope.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?
scope = scope.where(completed: params[:status] == "done") if params[:status].present?
scope = scope.where(priority: params[:priority])          if params[:priority].present?
```

O `ILIKE '%termo%'` aproveita o índice GIN trigram — sem ele a query faria seq scan.

---

## Arquitetura de Audit Log

Logs disparados **explicitamente** em controllers e no `Pajem::Tools` — sem callbacks no model.

**Motivo:** callbacks são implícitos e não têm acesso fácil à `origin` (manual vs assistente). Chamadas explícitas são mais claras e testáveis.

```ruby
# app/models/audit_log.rb
class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  def self.record(user:, record:, action:, origin: :manual, changes: nil)
    create!(
      user:,
      auditable: record,
      action:,
      origin:,
      changes:
    )
  end
end
```

Uso em controller:
```ruby
def destroy
  @list.discard
  AuditLog.record(user: current_user, record: @list, action: :deleted)
  redirect_to lists_path
end
```

---

## Arquitetura de Compartilhamento Público

Listas compartilhadas são acessíveis sem autenticação via `share_token`.

```
GET /shares/:token
  └─▶ SharesController#show
        └─▶ List.find_by!(share_token: params[:token], share_enabled: true)
              └─▶ renderiza view pública (sem navbar, sem ações)
                  └─▶ items: list.items.kept  (soft deleted não aparecem)
```

O `SharesController` **não herda** `require_auth` do `ApplicationController`. É o único endpoint público além de login/cadastro.

---

## Frontend: Hotwire

Sem JavaScript customizado além de Stimulus controllers pontuais.

| Mecanismo       | Uso no Pajem                                               |
|-----------------|------------------------------------------------------------|
| Turbo Drive     | Navegação entre páginas sem reload completo                |
| Turbo Frames    | Formulários inline de criar/editar item sem sair da página |
| Turbo Streams   | Atualização da barra de progresso ao marcar item; stream do chat do Pajem |
| Stimulus        | Toggle dark mode, scroll automático do chat, color picker  |

**Responsividade (F-10)** via CSS puro — sem framework de grid externo:
- Layout base em Flexbox/Grid com breakpoints definidos como CSS custom properties
- Navbar colapsa para menu hambúrguer em telas < 640px (Stimulus controller)
- Chat do Pajem renderizado em painel lateral no desktop e em tela cheia no mobile
- Nenhum componente usa largura fixa em px — todos usam `%`, `rem` ou `clamp()`

**Dark mode** via Stimulus + CSS custom properties:
```javascript
// toggle salva em localStorage, adiciona classe 'dark' no <html>
// CSS: html.dark { --bg: #1a1a1a; --text: #f5f5f5; ... }
```

---

## Isolamento e Segurança

| Regra | Implementação |
|---|---|
| Usuário só acessa seus dados | Todo query parte de `current_user.lists`, `current_user.items`, etc. |
| Pajem opera no escopo do usuário | `Pajem::Tools` recebe `user:` e nunca busca sem ele |
| Link público é read-only | `SharesController` não tem nenhuma rota de escrita |
| Contas desativadas não entram | `current_user` usa `User.kept` — `deleted_at` bloqueia o login |
| Token de reset expira | Validado: `reset_password_sent_at > 2.hours.ago` antes de processar |
| CSRF | Rails default (`protect_from_forgery`) |

---

## Fluxo de uma Requisição Típica

**Exemplo: marcar item como concluído**

```
PATCH /items/:id/complete   (Turbo Stream request)
  │
  ├─▶ ItemsController#complete
  │     ├─ current_user.items.kept.find(params[:id])   ← scoped, seguro
  │     ├─ item.update!(completed: true, completed_at: Time.current)
  │     ├─ AuditLog.record(user: current_user, record: item, action: :completed)
  │     └─ respond_to :turbo_stream
  │
  └─▶ Turbo Stream
        ├─ replace "item_#{id}" → checkbox marcado
        └─ replace "list_progress_#{list_id}" → barra de progresso atualizada
```

---

## Decisões Arquiteturais

| Decisão | Alternativa descartada | Motivo |
|---|---|---|
| Monolito Rails com Hotwire | API + React/Next.js | Prazo de 2 dias — Hotwire entrega interatividade com muito menos código |
| Auth própria | Devise | Controle total sobre o fluxo, sem monkey-patching, mais didático para um case |
| `discard` para soft delete | `paranoia` | Paranoia usa `default_scope` que causa bugs sutis em queries com joins |
| Audit log explícito | Callbacks no model | Callbacks não têm contexto de `origin` (manual vs IA); chamada explícita é mais clara |
| Serviço `Pajem::Assistant` | Lógica no controller | Loop agêntico é complexo demais para controller — serviço isola e permite teste unitário |
| Confirmação de delete via chat | Modal JS | Mantém o fluxo dentro do chat, mais coerente com a UX do assistente |
