# US-11 — Lixeira

**Task de origem:** T-11  
**Depende de:** US-08 (T-08)  
**Features relacionadas:** F-14 (Soft Delete), F-05 (Histórico de Ações)

---

## Contexto

Listas e Itens usam soft delete via `Discard::Model` (concern `SoftDeletable`) — ao excluir, `deleted_at` é preenchido e o registro some do escopo padrão `kept`. A Lixeira é a página que expõe esses registros descartados, permitindo restaurá-los ou destruí-los permanentemente.

`Context` não inclui `SoftDeletable` — exclusão de contexto é destrutiva desde T-06 e não aparece na lixeira.

A ação `restored` já está declarada em `AuditLog::VALID_ACTIONS` desde T-03, aguardando esta US.

---

## User Stories

**Como** usuário autenticado,  
**Quero** visualizar as listas e itens que excluí,  
**Para que** eu possa restaurá-los caso tenha excluído por engano, ou destruí-los permanentemente quando tiver certeza.

---

## Critérios de Aceitação

### 1. Página da Lixeira (`GET /lixeira`)

- [ ] Exibe dois blocos separados: **Listas excluídas** e **Itens excluídos**
- [ ] Cada entrada de lista exibe: título, cor (como indicador visual), data de exclusão
- [ ] Cada entrada de item exibe: título, nome da lista de origem (se a lista ainda existir; senão "lista removida"), data de exclusão
- [ ] Ordenação por `deleted_at DESC` em cada bloco (mais recentes primeiro)
- [ ] Bloco vazio exibe mensagem de estado vazio ("Nenhuma lista excluída", "Nenhum item excluído")
- [ ] Se ambos os blocos estiverem vazios: exibe estado vazio único ("A lixeira está vazia")
- [ ] Link para a lixeira disponível na sidebar (já previsto em US-05)

### 2. Restaurar lista

- [ ] `PATCH /lixeira/listas/:id/restaurar` chama `list.undiscard`
- [ ] A lista volta ao grid de post-its imediatamente (resposta via Turbo Stream — remove a entrada da lixeira sem reload)
- [ ] Exibe flash notice: "Lista restaurada com sucesso."
- [ ] Registra `AuditLog.record(action: "restored", auditable: list, origin: "manual")`
- [ ] Scoped por `current_user` — `404` para lista alheia

### 3. Restaurar item

- [ ] `PATCH /lixeira/itens/:id/restaurar` chama `item.undiscard`
- [ ] Se a lista pai também estiver descartada: **não restaura** — exibe flash alert: "Restaure a lista '#{list.title}' antes de restaurar este item."
- [ ] Em caso de sucesso: remove a entrada da lixeira via Turbo Stream e exibe flash notice: "Item restaurado com sucesso."
- [ ] Registra `AuditLog.record(action: "restored", auditable: item, origin: "manual")`
- [ ] Scoped por `current_user` — `404` para item alheio

### 4. Destruir permanentemente lista

- [ ] `DELETE /lixeira/listas/:id` chama `list.destroy`
- [ ] Destrói a lista e todos os seus itens (incluindo os descartados — `dependent: :destroy` já declarado no model)
- [ ] Remove a entrada da lixeira via Turbo Stream
- [ ] Não registra audit log (a exclusão original já foi registrada como `deleted`)
- [ ] Scoped por `current_user` — `404` para lista alheia

### 5. Destruir permanentemente item

- [ ] `DELETE /lixeira/itens/:id` chama `item.destroy`
- [ ] Remove a entrada da lixeira via Turbo Stream
- [ ] Não registra audit log
- [ ] Scoped por `current_user` — `404` para item alheio

### 6. Isolamento por usuário

- [ ] Listas: `current_user.lists.discarded`
- [ ] Itens: `current_user.items.discarded`
- [ ] Nenhuma query usa `List.discarded` ou `Item.discarded` sem escopo de usuário

### 7. Testes de controller (`test/controllers/trash_controller_test.rb`)

- [ ] `GET /lixeira` — exibe listas e itens do usuário; não exibe de outros usuários
- [ ] `PATCH /lixeira/listas/:id/restaurar` — restaura a lista; lista volta ao `kept`; `404` para lista alheia; `404` para lista não descartada
- [ ] `PATCH /lixeira/itens/:id/restaurar` — restaura o item; bloqueia se lista pai estiver descartada; `404` para item alheio
- [ ] `DELETE /lixeira/listas/:id` — destrói lista e itens; `404` para lista alheia
- [ ] `DELETE /lixeira/itens/:id` — destrói item; `404` para item alheio
- [ ] Requer autenticação em todas as actions

---

## Rotas

```ruby
get    "/lixeira",                         to: "trash#index",        as: :trash

patch  "/lixeira/listas/:id/restaurar",    to: "trash#restore_list", as: :restore_trash_list
delete "/lixeira/listas/:id",              to: "trash#destroy_list", as: :trash_list

patch  "/lixeira/itens/:id/restaurar",     to: "trash#restore_item", as: :restore_trash_item
delete "/lixeira/itens/:id",               to: "trash#destroy_item", as: :trash_item
```

---

## Estrutura do Controller

```ruby
class TrashController < ApplicationController
  def index
    @discarded_lists = current_user.lists.discarded.order(deleted_at: :desc)
    @discarded_items = current_user.items.discarded.includes(:list).order(deleted_at: :desc)
  end

  def restore_list
    list = current_user.lists.discarded.find(params[:id])
    list.undiscard
    AuditLog.record(user: current_user, action: "restored", auditable: list, origin: "manual")
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("trash_list_#{list.id}") }
      format.html { redirect_to trash_path, notice: "Lista restaurada com sucesso." }
    end
  end

  def restore_item
    item = current_user.items.discarded.find(params[:id])

    if item.list.discarded?
      return redirect_to trash_path,
        alert: "Restaure a lista '#{item.list.title}' antes de restaurar este item."
    end

    item.undiscard
    AuditLog.record(user: current_user, action: "restored", auditable: item, origin: "manual")
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("trash_item_#{item.id}") }
      format.html { redirect_to trash_path, notice: "Item restaurado com sucesso." }
    end
  end

  def destroy_list
    list = current_user.lists.discarded.find(params[:id])
    list.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("trash_list_#{list.id}") }
      format.html { redirect_to trash_path, notice: "Lista excluída permanentemente." }
    end
  end

  def destroy_item
    item = current_user.items.discarded.find(params[:id])
    item.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove("trash_item_#{item.id}") }
      format.html { redirect_to trash_path, notice: "Item excluído permanentemente." }
    end
  end
end
```

---

## Notas Técnicas

**`discarded` sem o default scope**  
O `SoftDeletable` define `default_scope { kept }`. Para acessar registros descartados é necessário usar o escopo explícito `discarded` (que já faz `unscope(where: :deleted_at).where.not(deleted_at: nil)`). O `includes(:list)` nos itens também precisa passar pela associação sem o default scope — como `belongs_to :list` não tem escopo restrito, isso funciona naturalmente, mas a lista pai pode estar descartada.

**Lista pai descartada**  
Ao carregar os itens descartados, a lista pai (`item.list`) pode estar descartada ou até destruída. Usar `includes(:list)` para evitar N+1, e tratar `item.list.nil?` (destruída) e `item.list.discarded?` (descartada mas existente) como casos distintos na view e no restore.

**`dom_id` dos elementos na lixeira**  
Os elementos recebem `id="trash_list_#{list.id}"` e `id="trash_item_#{item.id}"` (não o `dom_id` padrão, que poderia colidir com elementos da página principal se ambos carregassem no mesmo DOM). O Turbo Stream usa esses IDs para remoção.

**`list.undiscard` via Discard gem**  
O método `undiscard` limpa `deleted_at` e salva. Não lança exceção — verificar `undiscard` retornar `true`/`false` se necessário. Na prática, para um registro válido já persistido, sempre terá sucesso.

**Destructive confirm no frontend**  
O botão "Excluir permanentemente" deve exibir confirmação antes de submeter. Usar atributo nativo do Turbo:

```erb
<%= button_to "Excluir permanentemente", trash_list_path(list),
      method: :delete,
      data: { turbo_confirm: "Excluir '#{list.title}' permanentemente? Esta ação não pode ser desfeita." } %>
```

---

## Definition of Done

- [ ] `GET /lixeira` exibe listas e itens descartados separados em blocos, ordenados por data de exclusão
- [ ] Restauração de lista funciona e registra audit log com `action: "restored"`
- [ ] Restauração de item bloqueia quando lista pai está descartada
- [ ] Restauração de item funciona e registra audit log com `action: "restored"`
- [ ] Destruição permanente de lista (e seus itens) funciona
- [ ] Destruição permanente de item funciona
- [ ] Todas as actions respondem com Turbo Stream (remoção da entrada sem reload)
- [ ] Link "Lixeira" na sidebar aponta para `/lixeira`
- [ ] Todas as rotas protegidas por `require_login` e scoped por `current_user`
- [ ] `bundle exec rails test test/controllers/trash_controller_test.rb` verde
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
