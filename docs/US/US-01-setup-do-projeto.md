# US-01 — Setup do Projeto

**Task de origem:** T-01  
**Depende de:** nada  
**Features relacionadas:** todas (fundação da aplicação)

---

## Contexto

Antes de qualquer feature existir, o projeto Rails precisa estar inicializado com banco configurado, gems essenciais instaladas e infraestrutura de e-mail pronta. Esta US cobre tudo que é necessário para que um desenvolvedor clone o repositório, rode `rails db:create` e `rails server`, e tenha a aplicação de pé sem erros.

---

## User Stories

**Como** desenvolvedor do projeto,  
**Quero** ter o projeto Rails configurado com PostgreSQL, gems essenciais e mailer base,  
**Para que** eu possa começar a implementar as features sem bloqueios de infraestrutura.

---

## Critérios de Aceitação

### 1. Projeto Rails inicializado

- [X] Aplicação Rails 7.x criada com `rails new pajem --database=postgresql`
- [X] Repositório Git inicializado com `.gitignore` adequado para Ruby/Rails
- [X] Arquivo `.env` listado no `.gitignore` (nunca commitado)
- [X] Arquivo `.env.example` commitado com todas as variáveis necessárias (sem valores reais)

### 2. Banco de dados PostgreSQL via Docker

- [X] Arquivo `docker-compose.yml` criado na raiz do projeto com o serviço `db` (imagem `postgres:16`)
- [X] Variáveis `POSTGRES_USER`, `POSTGRES_PASSWORD` e `POSTGRES_DB` lidas do `.env` no `docker-compose.yml`
- [X] Volume nomeado configurado para persistência dos dados entre restarts do container
- [X] `config/database.yml` configurado para ler `DATABASE_URL` do `.env` (apontando para o container)
- [X] `docker compose up -d db` sobe o PostgreSQL sem erros
- [X] `rails db:create` executa sem erros nos ambientes `development` e `test` (com o container rodando)
- [X] Banco de desenvolvimento e banco de teste criados com sucesso

### 3. Gems essenciais instaladas e configuradas

- [X] Gem `discard` adicionada ao `Gemfile` e instalada via `bundle install`
- [X] Gem `dotenv-rails` adicionada ao `Gemfile` (grupos `:development, :test`) e instalada
- [X] `config/application.rb` carrega variáveis do `.env` via `dotenv-rails` no boot
- [X] `config.active_record.schema_format = :sql` definido em `config/application.rb` (necessário para preservar índices GIN do PostgreSQL)

### 4. Action Mailer configurado

- [X] `config/environments/development.rb` configurado com `config.action_mailer.delivery_method = :smtp`
- [X] Credenciais SMTP lidas exclusivamente de variáveis de ambiente via `.env`:
  - `SMTP_HOST`
  - `SMTP_PORT`
  - `SMTP_USERNAME`
  - `SMTP_PASSWORD`
  - `MAILER_FROM` (ex: `"Pajem <noreply@pajem.app>"`)
- [X] `config/environments/test.rb` com `delivery_method = :test` (sem envio real)
- [X] `config/environments/production.rb` com configuração SMTP idêntica à de development (lendo do ambiente)

### 5. Mailer base criado

- [X] `app/mailers/application_mailer.rb` com `default from: ENV.fetch("MAILER_FROM")`
- [X] `app/mailers/user_mailer.rb` criado com dois métodos:
  - `password_reset(user)` — e-mail de recuperação de senha
  - `account_reactivation(user)` — e-mail de reativação de conta
- [X] Views de e-mail criadas (HTML + texto puro) para cada método:
  - `app/views/user_mailer/password_reset.html.erb`
  - `app/views/user_mailer/password_reset.text.erb`
  - `app/views/user_mailer/account_reactivation.html.erb`
  - `app/views/user_mailer/account_reactivation.text.erb`
- [X] As views são placeholders funcionais (não precisam ter layout visual final)

### 6. Servidor sobe sem erros

- [X] `rails server` inicia sem exceções em desenvolvimento
- [X] Página inicial do Rails (`/`) retorna HTTP 200 (ou redirect esperado)
- [X] Nenhum warning crítico no boot (deprecation warnings aceitáveis)

---

## Notas Técnicas

**Banco via Docker Compose**  
O PostgreSQL roda em container local para padronizar o ambiente entre desenvolvedores e eliminar dependência de instalação nativa. O `docker-compose.yml` expõe a porta `5432` para o host, permitindo que o Rails conecte normalmente via `DATABASE_URL`. O container não substitui o Dockerfile de produção — é exclusivo para desenvolvimento local.

Exemplo mínimo de `docker-compose.yml`:

```yaml
services:
  db:
    image: postgres:16
    env_file: .env
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```



**`schema_format = :sql`**  
Necessário porque os índices GIN trigram (usados na busca em T-14) não são expressáveis com o `schema.rb` padrão do Rails. Com `:sql`, o Rails gera `db/structure.sql` em vez de `db/schema.rb`, preservando qualquer DDL customizado executado via `execute` nas migrations.

**`dotenv-rails` apenas em dev/test**  
Em produção, as variáveis de ambiente devem ser injetadas pela plataforma de deploy (Heroku, Fly.io, etc.) — não via `.env`. A gem já segue essa convenção por padrão quando adicionada apenas ao grupo `:development, :test`.

**Mailers como placeholder**  
Os métodos `password_reset` e `account_reactivation` do `UserMailer` são criados agora para garantir que a estrutura existe. O conteúdo real dos e-mails será detalhado nas US de autenticação (T-04) e configurações de conta (T-15).

**`discard` sem configuração adicional**  
A gem `discard` não requer inicializador — basta incluir `include Discard::Model` nos models em T-03. Instalar aqui garante que o `Gemfile.lock` já está resolvido.

---

## Variáveis de Ambiente Necessárias

Adicionar ao `.env.example`:

```
POSTGRES_USER=pajem
POSTGRES_PASSWORD=secret
POSTGRES_DB=pajem_development

DATABASE_URL=postgres://pajem:secret@localhost:5432/pajem_development

SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=user@example.com
SMTP_PASSWORD=secret
MAILER_FROM=Pajem <noreply@pajem.app>
```

---

## Definition of Done

- [X] Todos os critérios de aceitação marcados como concluídos
- [X] `docker compose up -d db` sobe o container sem erros
- [X] `rails db:create` executa sem erros (com o container rodando)
- [X] `rails server` sobe sem erros
- [X] `bundle exec rails test` roda (mesmo que sem testes — apenas verifica que o ambiente de test está íntegro)
- [X] `.env` não está no repositório; `.env.example` está commitado com todas as variáveis
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
