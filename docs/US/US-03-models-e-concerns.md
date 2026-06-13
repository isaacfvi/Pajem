# US-03 — Models e Concerns

**Task de origem:** T-03  
**Depende de:** US-02 (T-02)  
**Features relacionadas:** todas (camada de dados da aplicação)

---

## Contexto

Com o schema do banco criado, a próxima etapa é implementar os models ActiveRecord correspondentes a cada tabela: validações, associações, escopos e comportamentos. Dois concerns transversais também são criados aqui — `SoftDeletable` (wrapper do `discard`) e `Auditable` (define que o model pode ser referenciado em `audit_logs` via polimorfismo e expõe o método `AuditLog.record`). Nenhuma lógica de controller ou view entra nesta US.

---

## User Stories

**Como** desenvolvedor do projeto,  
**Quero** ter todos os models implementados com validações, associações e escopos corretos,  
**Para que** os controllers possam operar sobre dados válidos e isolados por usuário sem regras duplicadas.

---

## Critérios de Aceitação

### 1. Concern `SoftDeletable`

- [ ] Criado em `app/models/concerns/soft_deletable.rb`
- [ ] Faz `include Discard::Model` no model que o inclui
- [ ] Redefine o default scope para `kept` (registros com `deleted_at: nil`)
- [ ] Expõe os escopos `kept` e `discarded` para uso nos controllers

### 2. Concern `Auditable`

- [ ] Criado em `app/models/concerns/auditable.rb`
- [ ] Não registra audit logs via callbacks — apenas marca o model como auditável
- [ ] Expõe o class method `AuditLog.record(user:, action:, auditable:, origin:, changes: nil)` em `AuditLog` (não no concern)

### 3. Model `User`

- [ ] `include SoftDeletable`
- [ ] `has_secure_password`
- [ ] Associações:
  - [ ] `has_many :contexts, dependent: :destroy`
  - [ ] `has_many :lists, dependent: :destroy`
  - [ ] `has_many :items, dependent: :destroy`
  - [ ] `has_many :audit_logs, dependent: :nullify`
  - [ ] `has_many :chat_messages, dependent: :destroy`
- [ ] Validações:
  - [ ] `name`: presence
  - [ ] `email`: presence, format (`URI::MailTo::EMAIL_REGEXP`), uniqueness (case-insensitive)
  - [ ] `password`: length mínimo 12 (somente quando presente — `allow_nil: true` para updates sem troca de senha)
- [ ] Callback `before_save`: normaliza `email` para downcase
- [ ] Escopo padrão via `SoftDeletable` (`kept`)
- [ ] Método de instância `#active?` → `!discarded?`

### 4. Model `Context`

- [ ] Associações:
  - [ ] `belongs_to :user`
  - [ ] `has_many :lists, dependent: :nullify`
- [ ] Validações:
  - [ ] `name`: presence, `length: { maximum: 100 }`, uniqueness scoped a `user_id`
  - [ ] `user`: presence

### 5. Model `List`

- [ ] `include SoftDeletable`
- [ ] `include Auditable`
- [ ] Associações:
  - [ ] `belongs_to :user`
  - [ ] `belongs_to :context, optional: true`
  - [ ] `has_many :items, dependent: :destroy`
- [ ] Validações:
  - [ ] `title`: presence, `length: { maximum: 255 }`
  - [ ] `color`: format (`/\A#[0-9A-Fa-f]{6}\z/`), allow nil
  - [ ] `user`: presence
- [ ] Escopo padrão via `SoftDeletable` (`kept`)
- [ ] Método de instância `#progress` → porcentagem de itens concluídos sobre total de itens `kept` (retorna `0` se não há itens)
- [ ] Método de instância `#active_items` → `items.kept`

### 6. Model `Item`

- [ ] `include SoftDeletable`
- [ ] `include Auditable`
- [ ] Associações:
  - [ ] `belongs_to :list`
  - [ ] `belongs_to :user`
- [ ] Enum: `priority: { low: 0, medium: 1, high: 2 }, _prefix: true`
- [ ] Validações:
  - [ ] `title`: presence, `length: { maximum: 255 }`
  - [ ] `list`: presence
  - [ ] `user`: presence
- [ ] Escopo padrão via `SoftDeletable` (`kept`)
- [ ] Escopo `overdue` → `where("due_date < ? AND completed = false", Date.current)`
- [ ] Callback `before_save`: preenche `completed_at` ao marcar `completed: true`; limpa `completed_at` ao desmarcar

### 7. Model `AuditLog`

- [ ] Associações:
  - [ ] `belongs_to :user, optional: true`
  - [ ] `belongs_to :auditable, polymorphic: true`
- [ ] Validações:
  - [ ] `action`: presence, inclusion em `%w[created updated deleted restored completed uncompleted shared unshared]`
  - [ ] `origin`: presence, inclusion em `%w[manual assistant]`
  - [ ] `auditable`: presence
- [ ] Class method `AuditLog.record(user:, action:, auditable:, origin: "manual", changes: nil)` — cria o registro; não lança exceção se falhar (usa `create` não `create!`)
- [ ] **Sem callbacks** — registros são imutáveis após criação

### 8. Model `ChatMessage`

- [ ] Associações:
  - [ ] `belongs_to :user`
- [ ] Validações:
  - [ ] `role`: presence, inclusion em `%w[user assistant]`
  - [ ] `content`: presence
  - [ ] `user`: presence
- [ ] **Sem callbacks** — mensagens são imutáveis após criação

### 9. Testes de model (`test/models/`)

- [ ] `UserTest`: validações, `authenticate`, soft delete, `#active?`
- [ ] `ContextTest`: validações, uniqueness scoped a `user_id`
- [ ] `ListTest`: validações, `#progress`, escopo `kept`/`discarded`
- [ ] `ItemTest`: validações, enum `priority`, callback `completed_at`, escopo `overdue`, escopo `kept`/`discarded`
- [ ] `AuditLogTest`: `AuditLog.record` cria registro; falha silenciosa em caso de erro
- [ ] `ChatMessageTest`: validações de `role` e `content`

---

## Notas Técnicas

**Default scope via `SoftDeletable`**  
Usar `default_scope { kept }` no concern para que toda query parta de registros não deletados. Controllers que precisam acessar registros descartados (lixeira) chamam `unscoped` ou o escopo `discarded` explicitamente.

**Validação de `email` com `URI::MailTo::EMAIL_REGEXP`**  
Regex nativa do Ruby — sem dependência externa. Suficiente para validação de formato básico. A unicidade é verificada no banco via índice UNIQUE, mas também declarada no model para mensagem de erro amigável.

**`password` com `allow_nil: true`**  
`has_secure_password` por padrão valida presença de senha em novos registros. A validação de comprimento mínimo com `allow_nil: true` permite que updates de outros campos (ex: nome) não exijam re-informar a senha.

**`AuditLog.record` não lança exceção**  
Usar `create` (não `create!`) garante que uma falha de auditoria não interrompa a ação principal. O controller deve logar o erro se `record` retornar `false`, mas não reverter a operação.

**Audit log nunca via callback**  
`Auditable` não registra logs automaticamente em `after_create`, `after_update`, etc. Cada controller chama `AuditLog.record` explicitamente após a operação — isso mantém a `origin` rastreável (`manual` vs `assistant`) e evita logs duplicados.

**`#progress` em `List`**  
```ruby
def progress
  total = items.kept.count
  return 0 if total.zero?
  (items.kept.where(completed: true).count.to_f / total * 100).round
end
```

**Enum `priority` com `_prefix: true`**  
Usar `_prefix` para evitar colisão com métodos genéricos: `item.priority_high?` em vez de `item.high?`.

---

## Definition of Done

- [ ] Todos os models criados com validações e associações corretas
- [ ] Concerns `SoftDeletable` e `Auditable` implementados e incluídos nos models corretos
- [ ] `AuditLog.record` implementado e testado
- [ ] `bundle exec rails test test/models` verde (todos os testes de model passando)
- [ ] Nenhuma lógica de controller ou view introduzida nesta US
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
