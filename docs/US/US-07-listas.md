# US-07 — Listas

**Task de origem:** T-07  
**Depende de:** US-06 (T-06)  
**Features relacionadas:** F-02 (Gerenciamento de Listas), F-11 (Barra de Progresso), F-12 (Cor Personalizada), F-13 (Contextos), F-14 (Soft Delete)

---

## Contexto

Listas são o objeto central da aplicação — cada lista agrupa itens (tarefas) e pode ter título, descrição, cor e contexto. Esta US implementa o CRUD completo de listas com soft delete, a barra de progresso atualizada em tempo real via Turbo Streams e o filtro por contexto na página principal. A expansão do post-it (estrutura visual) já foi definida em US-05 — aqui entram os dados reais e as ações.

---

## User Stories

**Como** usuário autenticado,  
**Quero** criar, editar e excluir listas com título, cor e contexto,  
**Para que** eu possa organizar minhas tarefas em grupos visuais e temáticos.

---

## Critérios de Aceitação

### 1. Listar listas (index)

- [ ] `GET /listas` exibe o grid de post-its com as listas ativas (`kept`) do `current_user`
- [ ] Aceita query param `context_id` para filtrar por contexto — `GET /listas?context_id=:id`
- [ ] `context_id` inválido ou de outro usuário é ignorado silenciosamente (exibe todas as listas)
- [ ] Lista vazia exibe mensagem de estado vazio com CTA para criar a primeira lista
- [ ] Cada post-it exibe: título, cor de fundo (ou padrão), quantidade de itens pendentes e barra de progresso

### 2. Criar lista

- [ ] `GET /listas/nova` renderiza formulário com campos: título (obrigatório), descrição (opcional), cor (color picker, opcional), contexto (dropdown com os contextos do usuário, opcional)
- [ ] `POST /listas` cria a lista vinculada ao `current_user`
- [ ] Em caso de sucesso: redireciona para `/listas` com `notice`
- [ ] Em caso de falha: re-renderiza formulário com erros (status `422`)

### 3. Editar lista

- [ ] `GET /listas/:id/editar` renderiza formulário pré-preenchido
- [ ] `PATCH /listas/:id` atualiza os campos permitidos: título, descrição, cor, contexto
- [ ] Em caso de sucesso: redireciona para `/listas` com `notice`
- [ ] Em caso de falha: re-renderiza formulário com erros (status `422`)
- [ ] Scoped por `current_user` — `404` se tentar editar lista alheia

### 4. Excluir lista (soft delete)

- [ ] `DELETE /listas/:id` preenche `deleted_at` via `list.discard`
- [ ] A lista some imediatamente do grid (não aparece mais no scope `kept`)
- [ ] Redireciona para `/listas` com `notice`
- [ ] Lista descartada pode ser visualizada e restaurada na Lixeira (US-11)
- [ ] Scoped por `current_user` — `404` se tentar excluir lista alheia

### 5. Cor personalizada

- [ ] Campo de cor usa `<input type="color">` no formulário
- [ ] Valor armazenado como hex `#RRGGBB` no campo `color`
- [ ] Sem cor selecionada: campo fica `nil` e o post-it usa `var(--color-bg-surface)`
- [ ] Botão para limpar a cor (setar `nil`) disponível no formulário de edição

### 6. Barra de progresso em tempo real

- [ ] Barra de progresso exibida em cada post-it: `itens concluídos / total de itens kept`
- [ ] Atualizada via Turbo Streams quando um item é marcado ou desmarcado como concluído (implementado em T-08 — a estrutura do stream target é definida aqui)
- [ ] Cada post-it tem um `turbo_frame_tag` ou `dom_id` que serve de alvo para o broadcast de T-08
- [ ] Sem itens: barra exibe `0%`

### 7. Isolamento por usuário

- [ ] Toda query é scoped por `current_user.lists.kept`
- [ ] Parâmetros de formulário não permitem sobrescrever `user_id`
- [ ] `404` para qualquer ação em lista de outro usuário

### 8. Testes de controller (`test/controllers/lists_controller_test.rb`)

- [ ] `GET /listas` — exibe listas do usuário; não exibe listas de outros usuários; filtra por `context_id`
- [ ] `POST /listas` — cria com dados válidos; falha sem título; falha com cor inválida
- [ ] `PATCH /listas/:id` — atualiza; `404` para lista alheia
- [ ] `DELETE /listas/:id` — faz soft delete; lista some do index; `404` para lista alheia
- [ ] Lista descartada não aparece no `GET /listas`

---

## Rotas

```ruby
resources :lists, path: "/listas", only: [:index, :new, :create, :edit, :update, :destroy]
```

---

## Notas Técnicas

**Soft delete com `discard`**  
Chamar `list.discard` em vez de `list.destroy`. O model já tem `include SoftDeletable` (T-03), que define o default scope como `kept`. Controllers sempre partem de `current_user.lists.kept.find(id)` — lista descartada retorna `404` automaticamente.

**Color picker**  
`<input type="color">` é nativo do browser — sem biblioteca. O valor padrão é `#000000` quando o campo está vazio, o que conflita com `nil` no banco. Solução: se o usuário não interagir com o campo de cor, enviar `nil` via campo oculto; o JS do color picker só ativa o valor quando o usuário clica no seletor.

```html
<input type="hidden" name="list[color]" value="">
<input type="color" name="list[color]" data-controller="color-picker">
```

**Turbo Frame target para barra de progresso**  
Cada post-it deve ter um `id` único para receber updates de Turbo Streams em T-08:

```erb
<div id="<%= dom_id(list, :progress) %>">
  <%= render "lists/progress_bar", list: list %>
</div>
```

**Filtro por `context_id` sem escopo quebrado**  
Se `context_id` for inválido ou de outro usuário, o filtro é silenciosamente ignorado — nunca levantar erro:

```ruby
@context = current_user.contexts.find_by(id: params[:context_id])
@lists = current_user.lists.kept
@lists = @lists.where(context_id: @context.id) if @context
```

**Audit log**  
`ListsController#create`, `#update` e `#destroy` chamam `AuditLog.record` com `origin: "manual"` e `auditable: list`. Em `#update`, passar `changes` com os atributos alterados via `list.saved_changes`.

---

## Definition of Done

- [ ] CRUD completo de listas funcionando (criar, editar, excluir com soft delete)
- [ ] Grid de post-its exibindo dados reais com cor e barra de progresso
- [ ] Filtro por contexto via query param funcionando na sidebar e na URL
- [ ] Turbo Frame target de progresso definido e pronto para T-08
- [ ] Cor personalizável com opção de limpar
- [ ] Todas as rotas protegidas por `require_login` e scoped por `current_user`
- [ ] `bundle exec rails test test/controllers/lists_controller_test.rb` verde
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
