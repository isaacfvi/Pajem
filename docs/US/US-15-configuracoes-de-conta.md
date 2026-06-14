# US-15 — Configurações de Conta

**Task de origem:** T-15  
**Depende de:** US-04 (T-04)  
**Features relacionadas:** F-17 (Desativação de Conta)

---

## Contexto

A coluna `deleted_at` na tabela `users` existe desde T-02. O `current_user` já usa `User.kept` desde T-04 — contas com `deleted_at` preenchido são tratadas como inexistentes no login, sem necessidade de alteração no `ApplicationController`.

O `UserMailer` com o método `account_reactivation` foi criado em T-01, aguardando implementação nesta US. O mecanismo de token reutiliza `reset_password_token` e `reset_password_sent_at` — colunas já presentes na tabela `users` — evitando nova migration.

O `AccountsController` já está previsto na estrutura de diretórios da aplicação.

---

## User Stories

**Como** usuário autenticado,  
**Quero** poder desativar minha conta ou excluir permanentemente todos os meus dados,  
**Para que** eu tenha controle sobre minha presença na plataforma e possa exercer meu direito de exclusão (GDPR).

---

## Critérios de Aceitação

### 1. Página de configurações de conta (`GET /conta`)

- [ ] Acessível via link "Configurações" ou "Minha conta" na navbar/sidebar
- [ ] Exibe nome e e-mail do usuário atual (somente leitura nesta US)
- [ ] Seção "Zona de perigo" com as duas opções destrutivas: desativar conta e excluir dados permanentemente
- [ ] Requer autenticação

### 2. Desativar conta

- [ ] `DELETE /conta` com `params[:action_type] == "deactivate"` — preenche `deleted_at: Time.current` no usuário
- [ ] Encerra a sessão (`session.delete(:user_id)`) imediatamente após desativar
- [ ] Redireciona para a página de login com flash notice: "Sua conta foi desativada. Você pode reativá-la a qualquer momento pelo link enviado ao seu e-mail."
- [ ] Envia e-mail de reativação via `UserMailer.account_reactivation(user).deliver_later`
- [ ] O e-mail contém um link de reativação com token válido por **48 horas**
- [ ] Botão de desativação exige confirmação via `data-turbo-confirm`
- [ ] Conta desativada tenta logar → `User.kept` não encontra o registro → `current_user` é `nil` → redirecionada para login com flash alert: "Conta desativada. Verifique seu e-mail para reativá-la."

### 3. Fluxo de reativação via e-mail

- [ ] `GET /conta/reativar/:token` — valida o token e a expiração (48 horas)
- [ ] Token válido: zera `deleted_at`, zera `reset_password_token` e `reset_password_sent_at`, inicia sessão e redireciona para `/` com notice: "Conta reativada com sucesso!"
- [ ] Token inválido ou expirado: redireciona para login com alert: "Link de reativação inválido ou expirado. Solicite um novo."
- [ ] `GET /conta/reativar/reenviar` — formulário para reenviar o e-mail de reativação (acessível sem autenticação)
- [ ] `POST /conta/reativar/reenviar` — busca o usuário por e-mail via `User.unscoped.find_by` (sem `kept`), gera novo token e reenvia o e-mail
- [ ] Se o e-mail não corresponder a uma conta desativada: exibe mensagem genérica sem revelar se o e-mail existe ("Se houver uma conta desativada associada a este e-mail, você receberá as instruções em breve.")

### 4. Excluir dados permanentemente (hard delete / GDPR)

- [ ] `DELETE /conta` com `params[:action_type] == "hard_delete"` — destrói o registro do usuário
- [ ] `User#destroy` em cascata remove: `contexts`, `lists`, `items`, `chat_messages` (via `dependent: :destroy` nos models)
- [ ] `audit_logs.user_id` vira `NULL` (via `ON DELETE SET NULL` no banco — comportamento já definido em T-02)
- [ ] Encerra a sessão antes de destruir o registro
- [ ] Redireciona para a página de login com flash notice: "Seus dados foram excluídos permanentemente."
- [ ] Botão exige confirmação via `data-turbo-confirm` com mensagem explícita: "Esta ação é irreversível. Todos os seus dados serão excluídos permanentemente. Tem certeza?"
- [ ] Não há recuperação possível após esta ação

### 5. Geração do token de reativação

- [ ] Reutiliza `reset_password_token` e `reset_password_sent_at` da tabela `users`
- [ ] Token gerado via `SecureRandom.urlsafe_base64(32)` — entropria suficiente para ser imprevisível
- [ ] `reset_password_sent_at` registra o momento da geração para controle de expiração de 48 horas
- [ ] Índice único parcial `idx_users_reset_password_token` (criado em T-02) garante unicidade

### 6. Isolamento e segurança

- [ ] Todas as actions do `AccountsController` requerem autenticação, exceto as rotas de reativação
- [ ] A rota de reativação busca usuários via `User.unscoped` (inclui desativados) — sem expor dados além do necessário
- [ ] Hard delete encerra a sessão **antes** de destruir o registro para evitar estado inconsistente

### 7. Testes (`test/controllers/accounts_controller_test.rb`)

- [ ] `GET /conta` — retorna 200; redireciona se não autenticado
- [ ] `DELETE /conta` (deactivate) — preenche `deleted_at`; encerra sessão; envia e-mail de reativação
- [ ] `DELETE /conta` (hard_delete) — destrói usuário e dados em cascata; encerra sessão
- [ ] `GET /conta/reativar/:token` — token válido: reativa e inicia sessão; token expirado: redireciona com alert; token inválido: redireciona com alert
- [ ] `POST /conta/reativar/reenviar` — e-mail existente desativado: envia novo token; e-mail inexistente: resposta genérica sem expor

---

## Rotas

```ruby
resource :conta, only: [ :show, :destroy ], path: "/conta" do
  collection do
    get  "reativar/reenviar",  to: "accounts#reactivation_form",  as: :reactivation_form
    post "reativar/reenviar",  to: "accounts#resend_reactivation", as: :resend_reactivation
    get  "reativar/:token",    to: "accounts#reactivate",          as: :reactivate
  end
end
```

---

## Estrutura do Controller

```ruby
class AccountsController < ApplicationController
  skip_before_action :require_login, only: [ :reactivation_form, :resend_reactivation, :reactivate ]

  def show; end

  def destroy
    if params[:action_type] == "hard_delete"
      session.delete(:user_id)
      current_user.destroy
      redirect_to login_path, notice: "Seus dados foram excluídos permanentemente."
    else
      current_user.update!(deleted_at: Time.current, **reactivation_token_attrs)
      UserMailer.account_reactivation(current_user).deliver_later
      session.delete(:user_id)
      redirect_to login_path, notice: "Sua conta foi desativada. Você pode reativá-la pelo link enviado ao seu e-mail."
    end
  end

  def reactivate
    user = User.unscoped.find_by(reset_password_token: params[:token])

    if user.nil? || user.reset_password_sent_at < 48.hours.ago
      return redirect_to login_path, alert: "Link de reativação inválido ou expirado. Solicite um novo."
    end

    user.update!(deleted_at: nil, reset_password_token: nil, reset_password_sent_at: nil)
    session[:user_id] = user.id
    redirect_to root_path, notice: "Conta reativada com sucesso!"
  end

  def reactivation_form; end

  def resend_reactivation
    user = User.unscoped.find_by(email: params[:email], deleted_at: ..Time.current)

    if user
      user.update!(reactivation_token_attrs)
      UserMailer.account_reactivation(user).deliver_later
    end

    redirect_to login_path, notice: "Se houver uma conta desativada associada a este e-mail, você receberá as instruções em breve."
  end

  private

  def reactivation_token_attrs
    { reset_password_token: SecureRandom.urlsafe_base64(32), reset_password_sent_at: Time.current }
  end
end
```

---

## Notas Técnicas

**Reutilização de `reset_password_token`**  
O campo `reset_password_token` foi projetado para recuperação de senha, mas serve igualmente para reativação de conta — ambos são fluxos de "link seguro por e-mail com expiração". Reutilizar evita uma nova coluna e nova migration. O único cuidado é garantir que um token de reativação pendente não seja usado para resetar a senha e vice-versa — como contas desativadas não fazem login, o risco de conflito é mínimo.

**`User.unscoped` nas rotas públicas**  
O `current_user` usa `User.kept`, que exclui registros com `deleted_at` preenchido. Para reativar uma conta, é necessário usar `User.unscoped.find_by(reset_password_token:)` para encontrar o usuário desativado sem passar pelo scope padrão.

**Cascata no hard delete**  
O `user.destroy` dispara os `dependent: :destroy` nos models:
- `User has_many :contexts, dependent: :destroy`
- `User has_many :lists, dependent: :destroy`
- `User has_many :items, dependent: :destroy`
- `User has_many :chat_messages, dependent: :destroy`
- `audit_logs.user_id` vira `NULL` via constraint `ON DELETE SET NULL` no banco (não passa pelo Rails)

**Mensagem genérica no reenvio**  
`resend_reactivation` sempre redireciona com a mesma mensagem, independente de o e-mail existir ou não. Isso previne enumeração de contas (user enumeration attack).

**`deleted_at: ..Time.current` no `resend_reactivation`**  
O range `..Time.current` é equivalente a `WHERE deleted_at <= NOW()`, garantindo que apenas contas efetivamente desativadas recebam o reenvio.

**Sessão encerrada antes do destroy**  
No hard delete, `session.delete(:user_id)` é chamado antes de `current_user.destroy`. Se a ordem fosse invertida, o registro estaria destruído mas a sessão ainda apontaria para um ID inexistente — causando erros nas próximas requisições.

---

## Definition of Done

- [ ] `GET /conta` exibe página de configurações com seção "Zona de perigo"
- [ ] Desativação de conta: preenche `deleted_at`, encerra sessão, envia e-mail de reativação
- [ ] Conta desativada bloqueada no login com mensagem orientando reativação
- [ ] `GET /conta/reativar/:token` reativa conta com token válido; rejeita token inválido ou expirado
- [ ] `POST /conta/reativar/reenviar` reenvia e-mail sem revelar existência da conta
- [ ] Hard delete: destrói usuário e todos os dados em cascata; encerra sessão antes
- [ ] Ambas as ações destrutivas exigem confirmação via `data-turbo-confirm`
- [ ] `UserMailer#account_reactivation` implementado e enviado com `deliver_later`
- [ ] Rotas de reativação acessíveis sem autenticação
- [ ] `bundle exec rails test test/controllers/accounts_controller_test.rb` verde
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
