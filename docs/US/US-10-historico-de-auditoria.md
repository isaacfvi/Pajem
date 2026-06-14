# US-10 — Histórico de Auditoria

**Task de origem:** T-10  
**Depende de:** US-09 (T-09)  
**Features relacionadas:** F-05 (Histórico de Ações / Audit Log)

---

## Contexto

O modelo `AuditLog` e sua migration já existem desde T-03. A tabela registra cada ação sobre `List`, `Item` e `Context` com os campos: `user_id`, `auditable_type`, `auditable_id`, `action`, `origin`, `changeset` (jsonb) e `created_at`. As chamadas a `AuditLog.record` já estão presentes nos controllers e em `Pajem::Tools`.

Esta US tem duas frentes:

1. **Fechar as lacunas de instrumentação** — garantir que todos os controllers passem `origin: "manual"` explicitamente e incluam `changes:` nas ações de atualização.
2. **Construir a página de histórico** — uma timeline paginada dos eventos do usuário, com filtros por data e tipo de ação.

---

## User Stories

**Como** usuário autenticado,  
**Quero** consultar um histórico de todas as ações realizadas nas minhas listas e itens,  
**Para que** eu possa acompanhar o que foi feito manualmente e pelo Pajem, com datas e detalhes.

---

## Critérios de Aceitação

### 1. Instrumentação dos controllers

- [ ] `ListsController#create`, `#update` e `#destroy` chamam `AuditLog.record` com `origin: "manual"` explícito
- [ ] `ListsController#update` passa `changes: @list.saved_changes`
- [ ] `ItemsController#create`, `#update`, `#toggle` e `#destroy` chamam `AuditLog.record` com `origin: "manual"` explícito
- [ ] `ItemsController#update` passa `changes: @item.saved_changes`
- [ ] `ContextsController#create`, `#update` e `#destroy` chamam `AuditLog.record` com `origin: "manual"` explícito
- [ ] `ContextsController#update` passa `changes: @context.saved_changes`
- [ ] `Pajem::Tools` já usa `origin: "assistant"` — sem alterações necessárias

### 2. Página de histórico (`GET /historico`)

- [ ] Exibe os eventos do `current_user` em ordem cronológica decrescente (mais recentes primeiro)
- [ ] Cada entrada exibe:
  - [ ] Data e hora (formato: "14 jun 2026 às 15:32")
  - [ ] Origem: **Manual** ou **Pajem** (com distinção visual)
  - [ ] Tipo do recurso: Lista / Item / Contexto
  - [ ] Nome do recurso (ex: "Compras", "Miojo")
  - [ ] Ação realizada (ex: "criado", "concluído", "excluído")
  - [ ] Detalhes de mudança quando disponíveis (campos alterados via `changeset`)
- [ ] Paginação: 25 eventos por página

### 3. Filtros

- [ ] Filtro por **data** — campos "de" e "até" (`date_from`, `date_to`)
- [ ] Filtro por **tipo de ação** — dropdown com as ações válidas: criado, atualizado, excluído, concluído, desmarcado
- [ ] Filtro por **origem** — Manual / Pajem / Todas
- [ ] Filtros combinados funcionam simultaneamente
- [ ] Filtros refletem na URL como query params (`?action=created&origin=assistant&date_from=2026-06-01`)
- [ ] Sem resultados exibe mensagem de estado vazio

### 4. Isolamento por usuário

- [ ] Toda query parte de `current_user.audit_logs` — nunca expõe eventos de outros usuários
- [ ] Recurso cujo `auditable` foi deletado permanentemente ainda exibe o registro, com nome em fallback ("recurso removido")

### 5. Testes de controller (`test/controllers/audit_logs_controller_test.rb`)

- [ ] `GET /historico` — exibe eventos do usuário; não exibe eventos de outros usuários
- [ ] Filtro por `action` retorna apenas os eventos correspondentes
- [ ] Filtro por `origin` retorna apenas manual ou assistant
- [ ] Filtro por `date_from` e `date_to` respeita o intervalo
- [ ] Combinação de filtros funciona corretamente
- [ ] Requer autenticação — redireciona se não autenticado

---

## Rotas

```ruby
get "/historico", to: "audit_logs#index", as: :audit_logs
```

---

## Estrutura do Controller

```ruby
class AuditLogsController < ApplicationController
  def index
    @audit_logs = current_user.audit_logs
                               .includes(:auditable)
                               .order(created_at: :desc)

    @audit_logs = @audit_logs.where(action: params[:action])   if params[:action].present?
    @audit_logs = @audit_logs.where(origin: params[:origin])   if params[:origin].present?
    @audit_logs = @audit_logs.where("created_at >= ?", params[:date_from].to_date) if params[:date_from].present?
    @audit_logs = @audit_logs.where("created_at <= ?", params[:date_to].to_date.end_of_day) if params[:date_to].present?

    @audit_logs = @audit_logs.page(params[:page]).per(25)
  end
end
```

---

## Notas Técnicas

**Associação `has_many :audit_logs` no `User`**  
Para `current_user.audit_logs` funcionar, o model `User` precisa de:

```ruby
has_many :audit_logs, dependent: :nullify
```

**Recurso removido permanentemente**  
`auditable` pode ser `nil` se o registro foi destruído (não soft-deleted). A view deve tratar com:

```erb
<%= audit_log.auditable&.title || "recurso removido" %>
```

**Tradução das ações e origens**  
Centralizar as labels de exibição no helper ou numa constante no model:

```ruby
ACTION_LABELS = {
  "created"     => "criado",
  "updated"     => "atualizado",
  "deleted"     => "excluído",
  "completed"   => "concluído",
  "uncompleted" => "desmarcado",
  "restored"    => "restaurado"
}.freeze

ORIGIN_LABELS = {
  "manual"    => "Manual",
  "assistant" => "Pajem"
}.freeze
```

**Paginação**  
Usar a gem `kaminari` (já presente no projeto se T-03 a incluiu) ou `pagy`. A query é paginada antes de chegar à view.

**`saved_changes` no momento correto**  
`saved_changes` só tem valor imediatamente após o `save`. Passar antes do redirect:

```ruby
def update
  if @list.update(list_params)
    AuditLog.record(user: current_user, action: "updated", auditable: @list,
                    origin: "manual", changes: @list.saved_changes)
    redirect_to lists_path, notice: "Lista atualizada."
  else
    render :edit, status: :unprocessable_entity
  end
end
```

**Índice no banco**  
A migration de T-03 já criou `idx_audit_logs_user_recent ON audit_logs(user_id, created_at DESC)` — a query principal de listagem usa esse índice sem configuração adicional.

---

## Definition of Done

- [ ] Todos os controllers passam `origin: "manual"` explicitamente e incluem `changes:` nas ações de update
- [ ] `GET /historico` exibe a timeline do usuário com data, origem, recurso e ação
- [ ] Filtros por data, ação e origem funcionando via query params
- [ ] Paginação de 25 registros por página
- [ ] Recurso removido exibe fallback sem erro
- [ ] Rota protegida por `require_login` e scoped por `current_user`
- [ ] `bundle exec rails test test/controllers/audit_logs_controller_test.rb` verde
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
