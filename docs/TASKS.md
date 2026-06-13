# Pajem — Macro Tasks

> Ordem de execução do projeto. Cada task é um card independente — agentes de detalhamento devem consultar `FEATURES.md`, `DATABASE.md` e `ARCHITECTURE.md` para expandir cada uma.

---

## T-01 — Setup do Projeto

Criar o projeto Rails, configurar o banco PostgreSQL, instalar e configurar as gems essenciais (`discard`, `dotenv-rails`) e definir o `schema_format :sql`. Configurar o Action Mailer com as credenciais SMTP via variáveis de ambiente (lidas do `.env` via `dotenv-rails`) e criar os mailer classes base: `UserMailer` com os métodos `password_reset` e `account_reactivation`. Verificar que o `rails db:create` e `rails server` sobem sem erros.

**Depende de:** nada

---

## T-02 — Migrations

Criar todas as migrations na ordem correta respeitando as foreign keys: `users` → `contexts` → `lists` → `items` → `audit_logs` → `chat_messages`. Incluir índices simples, compostos e parciais. Ativar a extensão `pg_trgm` e criar os índices GIN para busca.

**Depende de:** T-01

---

## T-03 — Models e Concerns

Implementar todos os models ActiveRecord com validações, associações e escopos. Criar os concerns `SoftDeletable` (wrapper do `discard`) e `Auditable`. Incluir o enum `priority` em `Item`, o `has_secure_password` em `User` e os escopos de soft delete em `List` e `Item`.

**Depende de:** T-02

---

## T-04 — Autenticação

Implementar cadastro, login, logout e recuperação de senha via e-mail. Criar `ApplicationController` com `current_user` (via `User.kept`) e `require_auth`. Proteger todas as rotas autenticadas. Sem Devise — auth própria com sessão Rails.

**Depende de:** T-03

---

## T-05 — Layout Base e Sistema Visual

Criar o layout principal (`application.html.erb`) com navbar, flash messages e área de conteúdo. Definir CSS custom properties para o sistema de cores (claro e escuro). Implementar o toggle de dark mode com Stimulus, persistindo preferência no `localStorage`.

**Depende de:** T-04

---

## T-06 — Contextos

CRUD completo de contextos: criar, renomear e excluir. Ao excluir, as listas associadas ficam com `context_id: null` (comportamento garantido pelo banco via `ON DELETE SET NULL`). Interface simples, acessível a partir das configurações ou da página de listas.

**Depende de:** T-05

---

## T-07 — Listas

CRUD completo de listas com título, descrição, cor (color picker) e contexto (dropdown). Barra de progresso calculada em tempo real via Turbo Streams ao marcar itens. Filtro por contexto na página principal de listas. Soft delete ao excluir.

**Depende de:** T-06

---

## T-08 — Itens

CRUD completo de itens dentro de uma lista. Marcar e desmarcar como concluído via Turbo Streams (atualiza item e barra de progresso da lista sem reload). Campos de `due_date` e `priority`. Destaque visual para itens vencidos. Soft delete ao excluir.

**Depende de:** T-07

---

## T-09 — Assistente Pajem

Implementar o serviço `Pajem::Assistant` com loop agêntico, `Pajem::Tools` com todas as 11 tools e `Pajem::ToolDefinitions` com os schemas JSON. Criar o `PajemController` e a interface de chat com Turbo Streams. Implementar o fluxo de confirmação para ações destrutivas via `metadata` em `ChatMessage`.

**Depende de:** T-08

---

## T-10 — Audit Logs

Adicionar chamadas explícitas a `AuditLog.record` em todos os controllers e em `Pajem::Tools`, passando a `origin` correta (`:manual` ou `:assistant`). Criar a página de histórico de auditoria com filtros por data e tipo de ação.

**Depende de:** T-09

---

## T-11 — Lixeira

Criar o `TrashController` com a view que lista listas e itens com `deleted_at` preenchido. Implementar as ações de restaurar (zera `deleted_at`) e hard delete (exclusão permanente do banco). Garantir que o hard delete de uma lista apaga seus itens permanentemente também.

**Depende de:** T-08

---

## T-12 — Compartilhamento Público

Gerar `share_token` via `SecureRandom.urlsafe_base64` ao ativar o compartilhamento de uma lista. Criar o `SharesController` fora do `require_auth`, renderizando a lista e seus itens ativos em uma view pública sem ações de edição. Permitir revogar ou desativar o link sem perder o token.

**Depende de:** T-07

---

## T-13 — Dashboard

Página inicial pós-login com contadores de listas ativas, itens pendentes e concluídos, itens vencidos e atividade recente (últimos registros de `audit_logs`). Dados calculados por queries diretas, sem cache.

**Depende de:** T-10

---

## T-14 — Busca e Filtros

Adicionar campo de busca nas páginas de listas e itens usando `ILIKE` com índice GIN trigram. Implementar filtros por status (pendente/concluído), prioridade e data de vencimento via query params. Filtros devem compor (todos aplicados simultaneamente).

**Depende de:** T-08

---

## T-15 — Configurações de Conta

Página de perfil com opção de desativar conta (soft delete no `User`) e hard delete completo de todos os dados (GDPR). Implementar reativação de conta via e-mail. Conta desativada é bloqueada no login por `User.kept`.

**Depende de:** T-04

---

## T-16 — Responsividade Mobile

Ajustar o layout para telas menores que 640px: navbar com menu hambúrguer (Stimulus), chat do Pajem em tela cheia no mobile, listas e itens em coluna única. Verificar todos os formulários e modais em viewport mobile. Nenhum elemento com largura fixa em px.

**Depende de:** T-13, T-15 (todas as views existentes)

---

## Mapa de Dependências

```
T-01 → T-02 → T-03 → T-04 → T-05 → T-06 → T-07 → T-08 → T-09 → T-10 → T-13
                                                          └──────────────▶ T-11
                                                          └──────────────▶ T-12
                                                          └──────────────▶ T-14
                              T-04 ──────────────────────────────────────▶ T-15
                                                              T-13, T-15 → T-16
```
