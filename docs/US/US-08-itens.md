# US-08 — Itens

**Task de origem:** T-08  
**Depende de:** US-07 (T-07)  
**Features relacionadas:** F-03 (Gerenciamento de Itens), F-06 (Datas e Prazos), F-07 (Prioridade), F-14 (Soft Delete)

---

## Contexto

Itens são as tarefas dentro de uma lista. Esta US implementa o CRUD completo de itens, o toggle de conclusão via Turbo Streams (sem reload de página), os campos de prazo (`due_date`) e prioridade, destaque visual para itens vencidos, e soft delete. O broadcast do Turbo Stream ao marcar/desmarcar um item também atualiza a barra de progresso da lista — conectando com o target definido em US-07.

---

## User Stories

**Como** usuário autenticado,  
**Quero** criar, editar, concluir e excluir itens dentro de uma lista,  
**Para que** eu possa gerenciar minhas tarefas com prazo e prioridade sem recarregar a página.

---

## Critérios de Aceitação

### 1. Criar item

- [ ] Formulário de criação acessível dentro da lista expandida (botão "**+ Novo Item**" de US-05)
- [ ] `POST /listas/:list_id/itens` cria o item vinculado ao `current_user` e à lista
- [ ] Campos: título (obrigatório), descrição (opcional), prazo — `due_date` (opcional), prioridade — `priority` (opcional: baixa / média / alta)
- [ ] Em caso de sucesso: insere o novo item na lista via Turbo Stream (sem redirect nem reload)
- [ ] Em caso de falha: exibe erros inline no formulário (status `422`)
- [ ] Item criado sempre começa com `completed: false`

### 2. Editar item

- [ ] `GET /listas/:list_id/itens/:id/editar` renderiza formulário pré-preenchido (via Turbo Frame inline na lista expandida)
- [ ] `PATCH /listas/:list_id/itens/:id` atualiza título, descrição, prazo e prioridade
- [ ] Em caso de sucesso: substitui o item na lista via Turbo Stream
- [ ] Em caso de falha: exibe erros inline (status `422`)
- [ ] Scoped por `current_user` — `404` para item alheio

### 3. Marcar / desmarcar como concluído

- [ ] Checkbox ou botão de toggle em cada item — `PATCH /listas/:list_id/itens/:id/toggle`
- [ ] Sem reload de página — resposta é Turbo Stream que:
  - [ ] Atualiza o visual do item (riscado, cor apagada, ícone de check)
  - [ ] Atualiza a barra de progresso da lista (target `dom_id(list, :progress)` definido em US-07)
- [ ] Ao marcar: preenche `completed_at` com o timestamp atual (via callback do model — US-03)
- [ ] Ao desmarcar: limpa `completed_at`
- [ ] Scoped por `current_user`

### 4. Excluir item (soft delete)

- [ ] `DELETE /listas/:list_id/itens/:id` preenche `deleted_at` via `item.discard`
- [ ] Remove o item da lista via Turbo Stream (sem reload)
- [ ] Atualiza a barra de progresso da lista via Turbo Stream
- [ ] Item descartado pode ser visualizado e restaurado na Lixeira (US-11)
- [ ] Scoped por `current_user` — `404` para item alheio

### 5. Prazo (`due_date`)

- [ ] Campo `<input type="date">` no formulário de criação e edição
- [ ] Item com prazo exibe a data formatada (ex: "15 jun")
- [ ] Item vencido (prazo anterior a hoje e não concluído) recebe destaque visual: cor vermelha / laranja (`var(--color-secondary)`) na data
- [ ] Item com prazo hoje recebe destaque em amarelo / laranja suave

### 6. Prioridade (`priority`)

- [ ] Campo de seleção com três opções: Baixa, Média, Alta
- [ ] Cada nível exibe um indicador visual no card do item (ex: barra colorida ou ícone)
  - [ ] Baixa — cor neutra
  - [ ] Média — laranja (`var(--color-secondary-light)`)
  - [ ] Alta — roxo (`var(--color-primary)`) ou vermelho
- [ ] Itens ordenados por padrão: não concluídos primeiro, depois por prioridade decrescente, depois por criação

### 7. Isolamento por usuário

- [ ] Toda query parte de `current_user.lists.kept.find(list_id)` antes de acessar o item
- [ ] `user_id` do item é sempre `current_user.id` — não aceito via params
- [ ] `404` para qualquer ação em item ou lista de outro usuário

### 8. Testes de controller (`test/controllers/items_controller_test.rb`)

- [ ] `POST /listas/:list_id/itens` — cria item válido via Turbo Stream; falha sem título
- [ ] `PATCH /listas/:list_id/itens/:id` — atualiza; `404` para item alheio
- [ ] `PATCH /listas/:list_id/itens/:id/toggle` — alterna `completed`; verifica `completed_at`; atualiza progresso da lista
- [ ] `DELETE /listas/:list_id/itens/:id` — soft delete; item some da lista; progresso atualizado
- [ ] Item vencido retorna destaque visual no HTML renderizado

---

## Rotas

```ruby
resources :lists, path: "/listas", only: [:index, :new, :create, :edit, :update, :destroy] do
  resources :items, path: "/itens", only: [:new, :create, :edit, :update, :destroy] do
    member do
      patch :toggle
    end
  end
end
```

---

## Notas Técnicas

**Turbo Stream no toggle e no soft delete**  
A resposta do `toggle` e do `destroy` deve ser um Turbo Stream com dois targets: o item em si e a barra de progresso da lista.

```ruby
# items_controller.rb
def toggle
  @item.update!(completed: !@item.completed)
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: [
        turbo_stream.replace(dom_id(@item), partial: "items/item", locals: { item: @item }),
        turbo_stream.replace(dom_id(@list, :progress), partial: "lists/progress_bar", locals: { list: @list })
      ]
    end
  end
end
```

**Ordenação padrão dos itens**  
```ruby
@items = @list.items.kept.order(completed: :asc, priority: :desc, created_at: :asc)
```
Itens não concluídos primeiro (`completed: :asc`), depois por prioridade alta primeiro (`priority: :desc`), depois por ordem de criação.

**Destaque de itens vencidos**  
Calculado na view — sem query extra:
```erb
<% if item.due_date.present? && item.due_date < Date.current && !item.completed %>
  class="item--overdue"
<% end %>
```

**Formulário de criação inline**  
O formulário de novo item fica dentro da lista expandida (Turbo Frame). Ao submeter com sucesso, o item é inserido no topo da lista via `turbo_stream.prepend` e o formulário é limpo (reset via Stimulus ou re-render do frame vazio).

**Audit log**  
`ItemsController#create`, `#update`, `#toggle` e `#destroy` chamam `AuditLog.record` com `origin: "manual"`. Para `toggle`, a `action` é `"completed"` ou `"uncompleted"` conforme o novo estado. Para `#update`, passa `changes: item.saved_changes`.

---

## Definition of Done

- [ ] CRUD completo de itens funcionando dentro da lista expandida
- [ ] Toggle de conclusão via Turbo Stream atualizando item e barra de progresso sem reload
- [ ] Soft delete de item via Turbo Stream removendo da lista e atualizando progresso
- [ ] Prazo exibido com destaque visual para itens vencidos e do dia
- [ ] Prioridade com indicador visual nos três níveis
- [ ] Ordenação padrão: não concluídos → prioridade → criação
- [ ] Todas as rotas protegidas por `require_login` e scoped por `current_user`
- [ ] `bundle exec rails test test/controllers/items_controller_test.rb` verde
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
