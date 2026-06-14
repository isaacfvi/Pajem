# US-13 — Dashboard

**Task de origem:** T-13  
**Depende de:** US-10 (T-10)  
**Features relacionadas:** F-08 (Dashboard)

---

## Contexto

O `DashboardController` já está previsto na estrutura de diretórios da aplicação. Esta US é a primeira tela que o usuário vê após o login — substitui qualquer redirect genérico para `/listas` e passa a ser a rota raiz autenticada.

Os dados são calculados via queries diretas, sem cache. Os índices criados em T-02 cobrem as queries principais:

- `idx_audit_logs_user_recent ON audit_logs(user_id, created_at DESC)` — atividade recente
- `idx_items_overdue_active ON items(user_id, due_date) WHERE due_date IS NOT NULL AND deleted_at IS NULL AND completed = false` — itens vencidos
- `idx_items_list_priority ON items(list_id, priority) WHERE deleted_at IS NULL` — distribuição por prioridade

Os gráficos são renderizados com **Chartkick** (wrapper de Chart.js) e **Groupdate** (GROUP BY por período via ActiveRecord). Filtros interativos nos gráficos são implementados em US-14.

---

## Gems

```ruby
# Gemfile
gem "chartkick"
gem "groupdate"
```

Chartkick requer a inclusão do Chart.js no layout:

```erb
<%# app/views/layouts/application.html.erb %>
<%= javascript_include_tag "https://www.gstatic.com/charts/loader.js" %>
<%= chartkick_j %>
```

Alternativa sem CDN externo: incluir o `chart.js` via import map ou assets pipeline.

---

## User Stories

**Como** usuário autenticado,  
**Quero** ver uma visão geral do estado das minhas listas e tarefas ao entrar na aplicação,  
**Para que** eu possa saber rapidamente o que está pendente, o que venceu e acompanhar minha produtividade ao longo do tempo.

---

## Critérios de Aceitação

### 1. Rota e acesso

- [ ] `GET /` (raiz autenticada) aponta para `dashboard#index`
- [ ] Requer autenticação — redireciona para login se não autenticado
- [ ] Link "Dashboard" (ou ícone de casa) na sidebar aponta para `/`

### 2. Contadores no topo

- [ ] **Listas ativas:** `current_user.lists.kept.count`
- [ ] **Itens pendentes:** itens `kept` com `completed: false`
- [ ] **Itens concluídos:** itens `kept` com `completed: true`
- [ ] **Itens vencidos:** itens `kept`, `completed: false`, `due_date < Date.today`
- [ ] Cada contador é um card clicável que leva à página correspondente

### 3. Gráfico: Itens concluídos por dia (bar chart)

- [ ] Exibe os últimos **7 dias** de itens concluídos, agrupados por `completed_at`
- [ ] Usa `group_by_day(:completed_at, range: 7.days.ago..Time.now).count` via Groupdate
- [ ] Dias sem conclusões aparecem com valor `0` (Groupdate preenche automaticamente)
- [ ] Escopo: `current_user.items.kept.where(completed: true)`
- [ ] Título do gráfico: "Itens concluídos nos últimos 7 dias"

### 4. Gráfico: Distribuição por prioridade (pie chart)

- [ ] Exibe a proporção de itens ativos (`kept`, `completed: false`) por prioridade
- [ ] Três fatias: **Baixa**, **Média**, **Alta** — itens sem prioridade (`nil`) aparecem como "Sem prioridade"
- [ ] Usa `.group(:priority).count` com mapeamento das labels via `Item::PRIORITY_LABELS`
- [ ] Se todos os itens não tiverem prioridade: exibe gráfico com fatia única "Sem prioridade"
- [ ] Título do gráfico: "Distribuição por prioridade"

### 5. Gráfico: Progresso por contexto (radar chart)

- [ ] Cada eixo do radar representa um contexto do usuário
- [ ] O valor de cada eixo é o **percentual de conclusão** do contexto: `itens_concluídos / total_itens * 100`
- [ ] Apenas itens `kept` (não deletados) são contabilizados
- [ ] Contextos sem nenhum item associado (via listas) exibem valor `0`
- [ ] Listas sem contexto (`context_id: nil`) **não** são incluídas no radar — o gráfico é exclusivo de workspaces nomeados
- [ ] Se o usuário não tiver contextos: o gráfico não é exibido e uma mensagem orienta a criar contextos
- [ ] Título do gráfico: "Progresso por contexto"

### 6. Itens com prazo próximo ou vencidos

- [ ] Exibe até **10 itens** com `due_date` preenchido, `completed: false` e `deleted_at IS NULL`, ordenados por `due_date ASC`
- [ ] Cada entrada exibe: título do item, nome da lista de origem, data de vencimento formatada e indicador de status
- [ ] Itens vencidos (`due_date < Date.today`) têm destaque visual (cor de alerta)
- [ ] Itens com vencimento hoje (`due_date == Date.today`) têm destaque visual distinto
- [ ] Se não houver itens com prazo: exibe estado vazio ("Nenhum item com prazo definido")

### 7. Atividade recente

- [ ] Exibe os **últimos 10 registros** de `audit_logs` do usuário, ordenados por `created_at DESC`
- [ ] Cada entrada exibe: data relativa, origem (Manual / Pajem) e descrição da ação
- [ ] Recurso deletado permanentemente exibe fallback "recurso removido"
- [ ] Link "Ver histórico completo" aponta para `/historico`

### 8. Isolamento por usuário

- [ ] Todas as queries partem de `current_user` — nunca expõem dados de outros usuários

### 9. Testes de controller (`test/controllers/dashboard_controller_test.rb`)

- [ ] `GET /` — retorna 200 para usuário autenticado; redireciona se não autenticado
- [ ] Contadores refletem apenas dados do `current_user`
- [ ] Dados dos gráficos escopados por `current_user`
- [ ] Radar chart ausente quando usuário não tem contextos

---

## Rotas

```ruby
root "dashboard#index"
```

---

## Estrutura do Controller

```ruby
class DashboardController < ApplicationController
  def index
    @lists_count     = current_user.lists.kept.count
    @pending_count   = current_user.items.kept.where(completed: false).count
    @completed_count = current_user.items.kept.where(completed: true).count
    @overdue_count   = current_user.items.kept
                                   .where(completed: false)
                                   .where("due_date < ?", Date.today).count

    @completed_by_day = current_user.items.kept
                                    .where(completed: true)
                                    .group_by_day(:completed_at, range: 7.days.ago..Time.now)
                                    .count

    @items_by_priority = current_user.items.kept
                                     .where(completed: false)
                                     .group(:priority)
                                     .count
                                     .transform_keys { |k| Item::PRIORITY_LABELS[k] || "Sem prioridade" }

    @progress_by_context = build_context_progress

    @upcoming_items = current_user.items.kept
                                  .where(completed: false)
                                  .where.not(due_date: nil)
                                  .includes(:list)
                                  .order(due_date: :asc)
                                  .limit(10)

    @recent_activity = current_user.audit_logs
                                   .includes(:auditable)
                                   .order(created_at: :desc)
                                   .limit(10)
  end

  private

  def build_context_progress
    current_user.contexts.includes(lists: :items).map do |context|
      items = context.lists.flat_map { |list| list.items.kept }
      total = items.count
      next nil if total.zero?

      completed = items.count(&:completed?)
      [ context.name, (completed.to_f / total * 100).round ]
    end.compact.to_h
  end
end
```

---

## Notas Técnicas

**`build_context_progress` em memória vs SQL**  
A implementação com `includes(lists: :items)` carrega os dados em Ruby. Para usuários com muitos contextos e listas, uma query SQL agregada é mais eficiente:

```ruby
def build_context_progress
  current_user.contexts
    .joins(lists: :items)
    .where(items: { deleted_at: nil })
    .group("contexts.id", "contexts.name")
    .select(
      "contexts.name",
      "COUNT(items.id) AS total",
      "SUM(CASE WHEN items.completed THEN 1 ELSE 0 END) AS completed_count"
    )
    .map { |r| [ r.name, r.total > 0 ? (r.completed_count.to_f / r.total * 100).round : 0 ] }
    .to_h
end
```

Usar a versão SQL para evitar N+1 em produção.

**`Item::PRIORITY_LABELS`**  
Constante no model para traduzir os valores do enum:

```ruby
PRIORITY_LABELS = {
  "low"    => "Baixa",
  "medium" => "Média",
  "high"   => "Alta",
  nil      => "Sem prioridade"
}.freeze
```

**Radar chart com dados vazios**  
Se `@progress_by_context` for vazio (usuário sem contextos ou contextos sem itens), não renderizar o `radar_chart` e exibir mensagem orientando a criar contextos:

```erb
<% if @progress_by_context.any? %>
  <%= radar_chart @progress_by_context, title: "Progresso por contexto", max: 100 %>
<% else %>
  <p>Crie contextos e associe listas a eles para ver o progresso aqui.</p>
<% end %>
```

**Destaque visual de prazo**  
CSS class definida na view:

```erb
<% css_class = if item.due_date < Date.today then "overdue"
                elsif item.due_date == Date.today then "due-today"
                else "" end %>
```

**Rota raiz com autenticação**  
O `before_action :require_login` do `ApplicationController` captura a raiz — usuários não autenticados são redirecionados para `/login`.

---

## Definition of Done

- [ ] `GET /` exibe dashboard com contadores, 3 gráficos, itens com prazo e atividade recente
- [ ] Rota raiz aponta para `dashboard#index`
- [ ] Bar chart exibe itens concluídos nos últimos 7 dias via Groupdate
- [ ] Pie chart exibe distribuição por prioridade dos itens ativos
- [ ] Radar chart exibe percentual de conclusão por contexto; ausente se não há contextos
- [ ] Itens vencidos têm destaque visual distinto
- [ ] Atividade recente exibe as últimas 10 ações com data relativa e origem
- [ ] Todas as queries escopadas por `current_user`
- [ ] `bundle exec rails test test/controllers/dashboard_controller_test.rb` verde
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
