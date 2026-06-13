# US-04 — Autenticação

**Task de origem:** T-04  
**Depende de:** US-03 (T-03)  
**Features relacionadas:** F-01 (Autenticação de Usuários), F-17 (Desativação de Conta — parcial)

---

## Contexto

Com os models prontos, esta US implementa o fluxo completo de acesso à aplicação: cadastro, login, logout e recuperação de senha por e-mail. A autenticação é própria — sem Devise — usando sessão Rails e `has_secure_password`. O `ApplicationController` recebe os helpers de autenticação (`current_user`, `require_login`) que serão reutilizados por todos os controllers da aplicação.

---

## User Stories

**Como** visitante,  
**Quero** criar uma conta e fazer login com e-mail e senha,  
**Para que** eu possa acessar minhas listas e tarefas de forma segura.

**Como** usuário autenticado,  
**Quero** poder fazer logout e recuperar minha senha por e-mail caso a esqueça,  
**Para que** eu mantenha controle de acesso à minha conta.

---

## Critérios de Aceitação

### 1. `ApplicationController` — helpers de autenticação

- [ ] `current_user` retorna `User.kept.find_by(id: session[:user_id])` (memoizado em `@current_user`)
- [ ] `user_signed_in?` retorna `current_user.present?`
- [ ] `require_login` redireciona para `login_path` com `alert` se não autenticado
- [ ] `require_no_login` redireciona para `root_path` se já autenticado
- [ ] Ambos declarados como `helper_method` para uso nas views

### 2. Cadastro (`RegistrationsController`)

- [ ] `GET /cadastro` renderiza formulário (`new`) — acessível apenas para visitantes (`before_action :require_no_login`)
- [ ] `POST /cadastro` cria o usuário e, em caso de sucesso:
  - [ ] Seta `session[:user_id]`
  - [ ] Redireciona para `root_path` com `notice`
- [ ] Em caso de falha: re-renderiza `new` com erros de validação (status `422`)
- [ ] Parâmetros permitidos: `name`, `email`, `password`, `password_confirmation`

### 3. Login (`SessionsController#new` e `#create`)

- [ ] `GET /login` renderiza formulário — acessível apenas para visitantes (`before_action :require_no_login`)
- [ ] `POST /login` com credenciais corretas:
  - [ ] Busca `User.kept.find_by(email: ...)` — conta descartada bloqueia o login
  - [ ] Verifica senha com `authenticate`
  - [ ] Seta `session[:user_id]`
  - [ ] Redireciona para `root_path` com `notice`
- [ ] `POST /login` com credenciais inválidas (e-mail inexistente, senha errada ou conta descartada):
  - [ ] Exibe mensagem genérica: `"E-mail ou senha inválidos."` — não revela qual campo está errado
  - [ ] Re-renderiza `new` (status `422`)
  - [ ] Não seta `session[:user_id]`

### 4. Logout (`SessionsController#destroy`)

- [ ] `DELETE /logout` limpa `session[:user_id]` com `reset_session`
- [ ] Redireciona para `login_path` com `notice`
- [ ] Acessível apenas para usuários autenticados (`before_action :require_login`)

### 5. Recuperação de senha

- [ ] `GET /senha/recuperar` renderiza formulário solicitando e-mail
- [ ] `POST /senha/recuperar`:
  - [ ] Busca `User.kept.find_by(email: ...)` — sem revelar se o e-mail existe (sempre exibe a mesma mensagem de sucesso)
  - [ ] Se usuário encontrado: gera `reset_password_token` via `SecureRandom.urlsafe_base64(32)`, preenche `reset_password_sent_at` e envia `UserMailer.password_reset(user).deliver_later`
  - [ ] Redireciona para `login_path` com `notice: "Se o e-mail existir, você receberá as instruções em breve."`
- [ ] `GET /senha/redefinir` renderiza formulário de nova senha (requer `token` no query param)
  - [ ] Token inválido ou expirado (> 2 horas): redireciona para `/senha/recuperar` com `alert`
- [ ] `PATCH /senha/redefinir`:
  - [ ] Valida token + expiração antes de atualizar
  - [ ] Em caso de sucesso: zera `reset_password_token` e `reset_password_sent_at`, redireciona para `login_path`
  - [ ] Em caso de falha de validação: re-renderiza formulário com erros (status `422`)

### 6. Proteção de rotas

- [ ] Todos os controllers (exceto `RegistrationsController`, `SessionsController` e `PasswordResetsController`) têm `before_action :require_login`
- [ ] Após login bem-sucedido, o usuário é redirecionado para a rota que tentava acessar (se houver `session[:return_to]`)

### 7. Testes de controller (`test/controllers/`)

- [ ] `RegistrationsControllerTest`: cadastro válido, cadastro com e-mail duplicado, cadastro com senha curta, visitante vs. autenticado
- [ ] `SessionsControllerTest`: login válido, credenciais erradas, conta descartada, logout
- [ ] `PasswordResetsControllerTest`: envio de e-mail, token válido, token expirado, redefinição com sucesso, senha inválida

---

## Rotas

```ruby
get    "/cadastro",          to: "registrations#new",           as: :new_registration
post   "/cadastro",          to: "registrations#create"

get    "/login",             to: "sessions#new",                as: :login
post   "/login",             to: "sessions#create"
delete "/logout",            to: "sessions#destroy",            as: :logout

get    "/senha/recuperar",   to: "password_resets#new",         as: :new_password_reset
post   "/senha/recuperar",   to: "password_resets#create"
get    "/senha/redefinir",   to: "password_resets#edit",        as: :edit_password_reset
patch  "/senha/redefinir",   to: "password_resets#update"
```

---

## Notas Técnicas

**`reset_session` no logout**  
Usar `reset_session` em vez de apenas `session.delete(:user_id)` — gera um novo session ID e invalida o anterior, prevenindo session fixation.

**Mensagem genérica em falha de login e recuperação de senha**  
Tanto credenciais inválidas quanto conta desativada retornam a mesma mensagem. Idem para recuperação de senha: o endpoint não revela se o e-mail está cadastrado. Ambos os comportamentos evitam enumeração de usuários.

**Expiração do token de recuperação**  
Token válido por 2 horas a partir de `reset_password_sent_at`. Verificação no controller:
```ruby
if user.reset_password_sent_at < 2.hours.ago
  redirect_to new_password_reset_path, alert: "Link expirado. Solicite um novo."
end
```

**`deliver_later` para envio de e-mail**  
Usa o Active Job em background — não bloqueia o request. Em desenvolvimento, o job roda inline se `config.active_job.queue_adapter = :inline` (ou similar).

**`session[:return_to]`**  
No `require_login`, salvar `session[:return_to] = request.fullpath` antes de redirecionar. Após login bem-sucedido, redirecionar para esse path e limpar a chave da session.

**Audit log no login/logout**  
`SessionsController#create` e `#destroy` registram no `Rails.logger` (não em `audit_logs` — sessão não é uma entidade auditável no schema).

---

## Definition of Done

- [ ] Controllers de cadastro, login, logout e recuperação de senha implementados
- [ ] `ApplicationController` com `current_user`, `require_login` e `require_no_login`
- [ ] Rotas definidas e nomeadas corretamente
- [ ] Views funcionais para todos os formulários (sem estilo final — layout base é T-05)
- [ ] `UserMailer#password_reset` com conteúdo real (HTML + texto)
- [ ] `bundle exec rails test test/controllers` verde
- [ ] Nenhuma rota protegida acessível sem autenticação
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
