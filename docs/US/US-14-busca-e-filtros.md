# US-14 — Busca e Filtros

**Task de origem:** T-14  
**Depende de:** US-08 (T-08), US-13 (T-13)  
**Features relacionadas:** F-09 (Busca e Filtros)

---

## Contexto

A infraestrutura de busca já existe desde T-02: a extensão `pg_trgm` está ativa e os índices GIN trigram nos campos `lists.title` e `items.title` estão criados. O `ILIKE '%termo%'` aproveita esses índices sem configuração adicional.

Esta US tem duas frentes:

1. **Busca e filtros nas páginas de listas e itens** — campos de busca por título e filtros compostos via query params.
2. **Filtros nos gráficos do dashboard** — controles de período e contexto que atualizam os gráficos via Turbo Frames sem reload da página.

---

## User Stories

**Como** usuário autenticado,  
**Quero** buscar e filtrar minhas listas e itens, e controlar o período e o escopo dos gráficos do dashboard,  
**Para que** eu possa encontrar o que preciso rapidamente e visualizar minha produtividade no contexto que me interessa.

---

## Critérios de Aceitação

### 1. Busca de listas (`GET /listas?q=termo`)

- [ ] Campo de busca no topo da página de listas
- [ ] Filtra listas cujo `title` contenha o termo (case-insensitive, via `ILIKE '%termo%'`)
- [ ] Combinável com o filtro de contexto já existente (`?context_id=1`)
- [ ] Query refletida na URL como `?q=termo` — campo mantém o valor ao recarregar
- [ ] Sem resultados: exibe estado vazio ("Nenhuma lista encontrada para '#{params[:q]}'")
- [ ] Limpar a busca: link "Limpar" remove o `q` da URL e volta ao estado sem filtro

### 2. Filtros de listas

- [ ] **Por contexto:** dropdown com os contextos do usuário + opção "Todos os contextos"
- [ ] `?context_id=` sem valor ou ausente → sem filtro de contexto
- [ ] Filtros compostos: `?q=termo&context_id=1` aplicam ambos simultaneamente

### 3. Busca de itens (`GET /listas/:id/itens?q=termo`)

- [ ] Campo de busca no topo da página de itens da lista
- [ ] Filtra itens cujo `title` contenha o termo (case-insensitive, via `ILIKE '%termo%'`)
- [ ] Query refletida na URL

### 4. Filtros de itens

- [ ] **Por status:** radio/dropdown com "Todos", "Pendentes", "Concluídos" (`?status=pending|done`)
- [ ] **Por prioridade:** dropdown com "Todas", "Baixa", "Média", "Alta" (`?priority=low|medium|high`)
- [ ] **Por prazo:** dropdown com "Todos", "Vencidos", "Vencem hoje", "Vencem esta semana" (`?due=overdue|today|week`)
- [ ] Todos os filtros compostos: aplicados simultaneamente
- [ ] Filtros refletem na URL como query params
- [ ] Sem resultados: exibe estado vazio

### 5. Filtro de período no bar chart do dashboard

- [ ] Controle de período com três opções: **7 dias** (default), **30 dias**, **90 dias**
- [ ] Implementado como form com `data-turbo-frame="chart-completed-by-day"` — atualiza apenas o frame do gráfico
- [ ] Query param: `?period=7|30|90`
- [ ] O gráfico exibe o título atualizado: "Itens concluídos nos últimos X dias"
- [ ] O restante do dashboard não é recarregado

### 6. Filtro de contexto no pie chart do dashboard

- [ ] Dropdown com "Todos os contextos" (default) e os contextos do usuário
- [ ] Implementado como form com `data-turbo-frame="chart-priority"` — atualiza apenas o frame do gráfico
- [ ] Query param: `?chart_context_id=1`
- [ ] Quando filtrado por contexto: pie chart exibe a distribuição de prioridade apenas dos itens das listas daquele contexto
- [ ] Quando "Todos os contextos": comportamento padrão da US-13
- [ ] O restante do dashboard não é recarregado

### 7. Radar chart — sem filtro adicional

- [ ] O radar chart não recebe filtro nesta US — sua natureza já é exibir todos os contextos comparativamente; filtrar quebraria o propósito do gráfico

### 8. Testes

- [ ] `test/controllers/lists_controller_test.rb`:
  - [ ] `?q=termo` retorna apenas listas cujo título contém o termo
  - [ ] `?context_id=1` retorna apenas listas do contexto
  - [ ] `?q=termo&context_id=1` aplica ambos
  - [ ] Não retorna listas de outros usuários em nenhum cenário
- [ ] `test/controllers/items_controller_test.rb`:
  - [ ] `?q=termo` retorna apenas itens cujo título contém o termo
  - [ ] `?status=pending` retorna apenas itens não concluídos
  - [ ] `?status=done` retorna apenas itens concluídos
  - [ ] `?priority=high` retorna apenas itens de alta prioridade
  - [ ] `?due=overdue` retorna apenas itens com `due_date < Date.today`
  - [ ] Combinações de filtros funcionam
- [ ] `test/controllers/dashboard_controller_test.rb`:
  - [ ] `?period=30` retorna dados dos últimos 30 dias no bar chart
  - [ ] `?chart_context_id=1` filtra o pie chart pelo contexto informado

---

## Alterações nos Controllers

### `ListsController#index`

```ruby
def index
  scope = current_user.lists.kept.includes(:context, :items)
  scope = scope.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?
  scope = scope.where(context_id: params[:context_id])    if params[:context_id].present?
  @lists = scope.order(created_at: :desc)
end
```

### `ItemsController#index`

```ruby
def index
  scope = @list.items.kept
  scope = scope.where("title ILIKE ?", "%#{params[:q]}%") if params[:q].present?

  scope = case params[:status]
          when "pending" then scope.where(completed: false)
          when "done"    then scope.where(completed: true)
          else scope
          end

  scope = scope.where(priority: params[:priority]) if params[:priority].present?

  scope = case params[:due]
          when "overdue" then scope.where("due_date < ?", Date.today)
          when "today"   then scope.where(due_date: Date.today)
          when "week"    then scope.where(due_date: Date.today..Date.today.end_of_week)
          else scope
          end

  @items = scope.order(completed: :asc, created_at: :asc)
end
```

### `DashboardController#index` (extensão de US-13)

```ruby
def index
  # ... contadores e upcoming_items inalterados ...

  period = (params[:period] || 7).to_i.clamp(1, 90)
  @completed_by_day = current_user.items.kept
                                  .where(completed: true)
                                  .group_by_day(:completed_at, range: period.days.ago..Time.now)
                                  .count
  @chart_period = period

  context_scope = if params[:chart_context_id].present?
                    current_user.items.kept
                                .joins(:list)
                                .where(lists: { context_id: params[:chart_context_id] })
                  else
                    current_user.items.kept
                  end

  @items_by_priority = context_scope
                         .where(completed: false)
                         .group(:priority)
                         .count
                         .transform_keys { |k| Item::PRIORITY_LABELS[k] || "Sem prioridade" }
end
```

---

## Turbo Frames no Dashboard

Cada gráfico filtrável é envolto em um Turbo Frame com ID único:

```erb
<%# Bar chart %>
<%= turbo_frame_tag "chart-completed-by-day" do %>
  <%= form_with url: root_path, method: :get, data: { turbo_frame: "chart-completed-by-day" } do |f| %>
    <%= f.select :period, [["7 dias", 7], ["30 dias", 30], ["90 dias", 90]],
          { selected: @chart_period }, { onchange: "this.form.requestSubmit()" } %>
  <% end %>
  <%= bar_chart @completed_by_day, title: "Itens concluídos nos últimos #{@chart_period} dias" %>
<% end %>

<%# Pie chart %>
<%= turbo_frame_tag "chart-priority" do %>
  <%= form_with url: root_path, method: :get, data: { turbo_frame: "chart-priority" } do |f| %>
    <%= f.select :chart_context_id,
          current_user.contexts.pluck(:name, :id).prepend(["Todos os contextos", ""]),
          { selected: params[:chart_context_id] }, { onchange: "this.form.requestSubmit()" } %>
  <% end %>
  <%= pie_chart @items_by_priority, title: "Distribuição por prioridade" %>
<% end %>
```

O `onchange: "this.form.requestSubmit()"` submete o form ao mudar o select, sem botão de submit explícito.

---

## Notas Técnicas

**`ILIKE` e injeção de SQL**  
Nunca interpolar `params[:q]` diretamente na string SQL. Usar sempre o placeholder `?`:

```ruby
scope.where("title ILIKE ?", "%#{params[:q]}%")
```

O `%` nos extremos é interpolado em Ruby antes de passar para o bind parameter — sem risco de SQL injection.

**Índices GIN trigram**  
O `ILIKE '%termo%'` sem índice faz seq scan. Os índices GIN em `lists.title` e `items.title` criados em T-02 garantem performance aceitável para buscas por substring. Sem eles, o ILIKE seria proibitivo em tabelas grandes.

**`clamp` no período do gráfico**  
`params[:period].to_i.clamp(1, 90)` previne que um usuário passe valores absurdos (`?period=99999`) que gerariam queries custosas.

**Turbo Frame e query params independentes**  
Cada Turbo Frame faz um GET no `root_path` com seus próprios params. O controller precisa preservar os demais params (contadores, upcoming_items) porque o frame recebe a página inteira e extrai apenas o frame pelo ID. Não há conflito entre `?period=30` e `?chart_context_id=1` — são requests independentes para frames distintos.

---

## Definition of Done

- [ ] Campo de busca por título funciona em listas e itens (case-insensitive)
- [ ] Filtros de lista: por contexto, combinável com busca
- [ ] Filtros de item: por status, prioridade e prazo, todos compostos
- [ ] Todos os filtros refletem na URL como query params
- [ ] Estado vazio exibido quando nenhum resultado encontrado
- [ ] Bar chart filtrável por período (7 / 30 / 90 dias) via Turbo Frame
- [ ] Pie chart filtrável por contexto via Turbo Frame
- [ ] Filtros dos gráficos atualizam apenas o frame correspondente, sem reload
- [ ] `bundle exec rails test test/controllers/lists_controller_test.rb` verde
- [ ] `bundle exec rails test test/controllers/items_controller_test.rb` verde
- [ ] `bundle exec rails test test/controllers/dashboard_controller_test.rb` verde
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
