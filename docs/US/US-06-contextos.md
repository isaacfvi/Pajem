# US-06 — Contextos

**Task de origem:** T-06  
**Depende de:** US-05 (T-05)  
**Features relacionadas:** F-13 (Contextos)

---

## Contexto

Contextos são agrupadores opcionais de listas (ex: "Trabalho", "Estudos", "Casa"). Um usuário pode ter vários contextos, cada lista pode pertencer a um contexto, e ao excluir um contexto as listas associadas continuam existindo — apenas ficam sem contexto (`context_id: null`). Esta US implementa o CRUD completo de contextos, incluindo o filtro por contexto na sidebar.

---

## User Stories

**Como** usuário autenticado,  
**Quero** criar, renomear e excluir contextos,  
**Para que** eu possa organizar minhas listas em categorias e filtrá-las facilmente.

---

## Critérios de Aceitação

### 1. Criar contexto

- [ ] `GET /contextos/novo` renderiza formulário com campo de nome
- [ ] `POST /contextos` cria o contexto vinculado ao `current_user`
- [ ] Em caso de sucesso: redireciona para a página de listas com filtro pelo novo contexto e exibe `notice`
- [ ] Em caso de falha (nome em branco ou duplicado): re-renderiza formulário com erro (status `422`)
- [ ] Após criação, o novo contexto aparece imediatamente na sidebar

### 2. Editar contexto

- [ ] `GET /contextos/:id/editar` renderiza formulário pré-preenchido com o nome atual
- [ ] `PATCH /contextos/:id` atualiza o nome
- [ ] Em caso de sucesso: redireciona para a página de listas com o contexto ativo e exibe `notice`
- [ ] Em caso de falha: re-renderiza formulário com erro (status `422`)
- [ ] Scoped por `current_user` — usuário não pode editar contextos de outro usuário (`404` se tentar)

### 3. Excluir contexto

- [ ] `DELETE /contextos/:id` exclui o contexto
- [ ] Listas associadas **não são excluídas** — ficam com `context_id: null` (garantido pelo `ON DELETE SET NULL` do banco)
- [ ] Redireciona para a página "Todas as listas" com `notice`
- [ ] Scoped por `current_user` — `404` se tentar excluir contexto alheio
- [ ] Não há soft delete em contextos — exclusão é permanente

### 4. Filtro por contexto

- [ ] A sidebar exibe cada contexto do usuário como link clicável
- [ ] Clicar em um contexto filtra as listas: `GET /listas?context_id=:id`
- [ ] O item do contexto ativo fica destacado na sidebar
- [ ] "Todas as listas" (sem filtro) é o estado padrão

### 5. Isolamento por usuário

- [ ] Toda query de contexto é scoped por `current_user.contexts`
- [ ] Tentativa de acessar, editar ou excluir contexto de outro usuário retorna `404`

### 6. Testes de controller (`test/controllers/contexts_controller_test.rb`)

- [ ] `GET /contextos/novo` — autenticado renderiza formulário; não autenticado redireciona para login
- [ ] `POST /contextos` — cria com nome válido; falha com nome em branco; falha com nome duplicado no mesmo usuário
- [ ] `PATCH /contextos/:id` — atualiza nome; falha com nome inválido; `404` para contexto de outro usuário
- [ ] `DELETE /contextos/:id` — exclui e verifica que listas associadas permanecem com `context_id: nil`; `404` para contexto alheio

---

## Rotas

```ruby
resources :contexts, path: "/contextos", only: [:new, :create, :edit, :update, :destroy]
```

> Não há página de listagem de contextos (`index`) — eles são gerenciados a partir da sidebar e do formulário de lista.

---

## Notas Técnicas

**Sem `index` próprio**  
Contextos não têm página dedicada de listagem. O usuário os vê na sidebar e os acessa para editar/excluir a partir do ícone de opções ao lado de cada item na sidebar.

**`ON DELETE SET NULL` — sem lógica no Rails**  
A desassociação das listas ao excluir um contexto é feita inteiramente pelo banco (constraint de FK definida em T-02). O Rails não precisa de `dependent: :nullify` no model `Context` — o banco garante a integridade. O model já declara `has_many :lists, dependent: :nullify` como documentação, mas o banco é a fonte de verdade.

**Unicidade de nome scoped por usuário**  
Dois usuários diferentes podem ter contextos com o mesmo nome. A validação de unicidade no model usa `uniqueness: { scope: :user_id }` e o banco garante com o índice `UNIQUE(user_id, name)` criado em T-02.

**Audit log**  
`ContextsController#create`, `#update` e `#destroy` chamam `AuditLog.record` explicitamente com `origin: "manual"`. O `auditable` é o contexto afetado.

---

## Definition of Done

- [ ] CRUD de contextos funcionando (criar, editar, excluir)
- [ ] Filtro por contexto na sidebar ativo e destacando o item correto
- [ ] Listas não são excluídas ao remover um contexto
- [ ] Todas as rotas protegidas por `require_login`
- [ ] Isolamento por `current_user` em todas as ações
- [ ] `bundle exec rails test test/controllers/contexts_controller_test.rb` verde
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
