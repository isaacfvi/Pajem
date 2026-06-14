# US-12 — Compartilhamento Público

**Task de origem:** T-12  
**Depende de:** US-07 (T-07)  
**Features relacionadas:** F-16 (Compartilhamento de Lista via Link Público)

---

## Contexto

As colunas `share_token` (string) e `share_enabled` (boolean, default `false`) já existem na tabela `lists` desde T-02. O índice parcial único `idx_lists_share_token ON lists(share_token) WHERE share_token IS NOT NULL` também já está criado — nenhuma migration é necessária nesta US.

A separação entre `share_token` e `share_enabled` é intencional: desativar o compartilhamento zera `share_enabled` mas preserva o token, permitindo reativá-lo no mesmo link. Revogar gera um novo token — invalidando permanentemente o link anterior.

O `SharesController` é o único endpoint público da aplicação além de login e cadastro — não herda `require_auth`.

---

## User Stories

**Como** usuário autenticado,  
**Quero** gerar um link público para uma lista,  
**Para que** qualquer pessoa com o link possa visualizá-la sem precisar de conta, e eu possa desativar ou revogar esse acesso a qualquer momento.

---

## Critérios de Aceitação

### 1. Ativar compartilhamento

- [ ] Botão "Compartilhar" disponível no painel expandido da lista
- [ ] `PATCH /listas/:id/compartilhar` com `share_enabled: true`:
  - [ ] Se `share_token` for `nil`: gera token via `SecureRandom.urlsafe_base64(16)` e salva junto com `share_enabled: true`
  - [ ] Se `share_token` já existir (foi gerado antes e o link foi desativado): apenas seta `share_enabled: true` — **não regenera o token**
- [ ] Após ativar: exibe o link público e opções de desativar / revogar (via Turbo Stream, sem reload)
- [ ] Registra `AuditLog.record(action: "shared", auditable: list, origin: "manual")`

### 2. Desativar compartilhamento

- [ ] `PATCH /listas/:id/compartilhar` com `share_enabled: false` (ou rota dedicada — ver Rotas)
- [ ] Seta `share_enabled: false` — **preserva o `share_token`**
- [ ] O link anterior para de funcionar imediatamente (controller verifica `share_enabled: true` na busca)
- [ ] Reativar usa o mesmo link — não gera um novo token
- [ ] Registra `AuditLog.record(action: "unshared", auditable: list, origin: "manual")`

### 3. Revogar link (regenerar token)

- [ ] `PATCH /listas/:id/revogar_link` — gera novo `SecureRandom.urlsafe_base64(16)` e salva com `share_enabled: true`
- [ ] O link anterior é invalidado permanentemente
- [ ] Exibe o novo link via Turbo Stream
- [ ] Registra `AuditLog.record(action: "shared", auditable: list, origin: "manual")`

### 4. Painel de compartilhamento na lista expandida

- [ ] Enquanto `share_enabled: false` (ou `share_token: nil`): exibe apenas o botão "Compartilhar"
- [ ] Enquanto `share_enabled: true`: exibe:
  - [ ] URL completa do link público (copiável)
  - [ ] Botão "Copiar link" (JS nativo `navigator.clipboard.writeText`)
  - [ ] Botão "Desativar link"
  - [ ] Botão "Revogar e gerar novo link" (com confirm antes de submeter)

### 5. View pública (`GET /c/:token`)

- [ ] Acessível **sem autenticação**
- [ ] Busca via `List.find_by!(share_token: params[:token], share_enabled: true)` — `404` se token não encontrado ou `share_enabled: false`
- [ ] Exibe: título da lista, lista de itens ativos (`items.kept`) com título, status de conclusão e prazo
- [ ] Itens com soft delete (`deleted_at` preenchido) **não** aparecem
- [ ] Layout mínimo: sem topbar, sem sidebar, sem ações de edição — apenas visualização
- [ ] Identidade visual da aplicação preservada (CSS, dark mode não necessário na view pública)
- [ ] Meta tag `<meta name="robots" content="noindex">` para não indexar em buscadores

### 6. Isolamento e segurança

- [ ] `ListsController` scopa as actions de share por `current_user.lists.kept`
- [ ] `SharesController#show` não expõe nenhum dado do usuário além do conteúdo da lista
- [ ] Token tem entropia suficiente para ser imprevisível: `SecureRandom.urlsafe_base64(16)` gera 128 bits
- [ ] Unicidade do token garantida pelo índice único no banco — em caso de colisão (extremamente improvável), o `save` falha e um novo token deve ser gerado

### 7. Testes

- [ ] `test/controllers/lists_controller_test.rb`:
  - [ ] `PATCH /listas/:id/compartilhar` — gera token; ativa link; requer autenticação; `404` para lista alheia
  - [ ] Desativar — preserva token; link público retorna 404 após desativar
  - [ ] `PATCH /listas/:id/revogar_link` — gera novo token; token anterior inválido
- [ ] `test/controllers/shares_controller_test.rb`:
  - [ ] `GET /c/:token` — exibe lista; exibe itens `kept`; não exibe itens descartados; não requer autenticação
  - [ ] Token inexistente → 404
  - [ ] `share_enabled: false` → 404
  - [ ] Lista com soft delete → 404 (list.kept não encontra a lista)

---

## Rotas

```ruby
resources :lists, path: "/listas", only: [ :index, :new, :create, :edit, :update, :destroy ] do
  member do
    patch :compartilhar    # ativa ou desativa share_enabled
    patch :revogar_link    # regenera share_token
  end
  resources :items, path: "/itens", only: [ :show, :create, :edit, :update, :destroy ] do
    member { patch :toggle }
  end
end

get "/c/:token", to: "shares#show", as: :share
```

---

## Estrutura dos Controllers

```ruby
# app/controllers/lists_controller.rb (actions adicionais)
def compartilhar
  if @list.share_enabled?
    @list.update!(share_enabled: false)
    AuditLog.record(user: current_user, action: "unshared", auditable: @list, origin: "manual")
  else
    @list.share_token ||= SecureRandom.urlsafe_base64(16)
    @list.share_enabled = true
    @list.save!
    AuditLog.record(user: current_user, action: "shared", auditable: @list, origin: "manual")
  end
  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to lists_path }
  end
end

def revogar_link
  @list.update!(share_token: SecureRandom.urlsafe_base64(16), share_enabled: true)
  AuditLog.record(user: current_user, action: "shared", auditable: @list, origin: "manual")
  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to lists_path }
  end
end
```

```ruby
# app/controllers/shares_controller.rb
class SharesController < ApplicationController
  skip_before_action :require_login

  def show
    @list  = List.unscoped.find_by!(share_token: params[:token], share_enabled: true)
    @items = @list.items.kept.order(completed: :asc, created_at: :asc)
    render layout: "share"
  end
end
```

---

## Notas Técnicas

**Layout separado para a view pública**  
A view pública usa `layout: "share"` — um layout mínimo em `app/views/layouts/share.html.erb` sem topbar, sidebar ou widget do Pajem. Compartilha o CSS da aplicação para manter a identidade visual, mas não renderiza componentes autenticados.

**`List.unscoped` no `SharesController`**  
O default scope de `List` filtra por `deleted_at IS NULL` (`kept`). O `SharesController` usa `List.unscoped.find_by!(share_token:, share_enabled:)` para fazer uma busca limpa e em seguida verificar as condições necessárias. Alternativamente, `List.kept.find_by!` funciona igualmente — a lista descartada naturalmente não será encontrada.

**Colisão de token**  
A probabilidade de colisão com `urlsafe_base64(16)` (128 bits) é negligenciável. Se ocorrer, o `save!` levantará `ActiveRecord::RecordNotUnique` (violação do índice único). O controller pode resgatar e tentar novamente, mas na prática não é necessário.

**`navigator.clipboard` para copiar o link**  
Disponível apenas em contextos seguros (HTTPS ou localhost). O botão "Copiar link" usa um Stimulus controller mínimo:

```javascript
// clipboard_controller.js
copy() {
  navigator.clipboard.writeText(this.urlValue)
    .then(() => { this.buttonTarget.textContent = "Copiado!" })
    .catch(() => { this.inputTarget.select() })
}
```

Fallback: seleciona o texto do input para que o usuário copie manualmente.

**`noindex` na view pública**  
A lista pública não deve ser indexada por buscadores, mas o conteúdo pode ser sensível. Adicionar no layout `share`:

```html
<meta name="robots" content="noindex, nofollow">
```

---

## Definition of Done

- [ ] Ativar compartilhamento gera token e exibe link público sem reload
- [ ] Desativar preserva token e invalida acesso imediatamente
- [ ] Revogar gera novo token, invalidando o link anterior permanentemente
- [ ] Painel de compartilhamento na lista expandida com botão de copiar link
- [ ] `GET /c/:token` acessível sem autenticação, com layout mínimo e `noindex`
- [ ] Itens descartados não aparecem na view pública
- [ ] Lista descartada não é acessível via link público
- [ ] `AuditLog.record` chamado em ativar, desativar e revogar
- [ ] `bundle exec rails test test/controllers/lists_controller_test.rb` e `test/controllers/shares_controller_test.rb` verdes
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
