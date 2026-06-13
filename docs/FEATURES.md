# Pajem — Documento de Features

> Aplicação de gerenciamento de tarefas inspirada nos pajens da Idade Média, onde um assistente leal executa suas ordens com precisão.

---

## Prioridades

| Símbolo | Nível      |
|---------|------------|
| 🔴      | Alta       |
| 🟡      | Média      |
| 🟢      | Baixa      |

---

## Features

### 🔴 F-01 — Autenticação de Usuários

Cada usuário terá sua própria conta, com acesso restrito aos seus próprios dados.

- Cadastro com nome, e-mail e senha
- Login e logout
- Recuperação de senha por e-mail
- Proteção de rotas (usuário não autenticado é redirecionado para login)
- Senhas armazenadas com hash seguro (bcrypt)

---

### 🔴 F-02 — Gerenciamento de Listas

O usuário poderá organizar suas tarefas em listas separadas.

- Criar lista (com título, descrição opcional, cor e contexto opcional)
- Editar lista
- Excluir lista (soft delete — registro permanece no banco)
- Visualizar todas as suas listas em uma página dedicada

---

### 🔴 F-03 — Gerenciamento de Itens de Lista

Cada lista contém itens (tarefas) que o usuário pode gerenciar individualmente.

- Criar item dentro de uma lista (com título e descrição opcional)
- Editar item
- Marcar item como concluído
- Desmarcar item como concluído
- Excluir item (soft delete — registro permanece no banco)
- Visualizar todos os itens de uma lista

---

### 🔴 F-04 — Assistente de IA "Pajem"

Um mini assistente com loop agêntico que interpreta comandos em linguagem natural e executa ações via ferramentas (tools/métodos).

**Ações disponíveis ao Pajem:**

| Tool               | Descrição                                              |
|--------------------|--------------------------------------------------------|
| `create_list`      | Cria uma nova lista para o usuário                     |
| `create_item`      | Adiciona um item a uma lista existente                 |
| `complete_item`    | Marca um item como concluído                           |
| `uncomplete_item`  | Desmarca um item como concluído                        |
| `delete_list`      | Exclui uma lista (solicita confirmação antes de agir)  |
| `delete_item`      | Exclui um item (solicita confirmação antes de agir)    |
| `list_lists`       | Lista as listas do usuário                             |
| `list_items`       | Lista os itens de uma lista                            |
| `list_contexts`    | Lista os contextos do usuário                          |
| `create_context`   | Cria um novo contexto                                  |
| `set_context`      | Associa uma lista a um contexto                        |

**Comportamento esperado:**
- Interface de chat integrada à aplicação
- O Pajem interpreta a intenção do usuário e executa a ação correspondente
- Para ações destrutivas (delete), o Pajem confirma com o usuário antes de executar
- Respostas em linguagem natural, mantendo o tom temático medieval

---

### 🟡 F-05 — Logs de Auditoria

Registro de todas as ações realizadas na aplicação, seja pelo usuário manualmente ou via Pajem.

- Log de criação, edição e exclusão de listas e itens
- Log das interações com o assistente Pajem
- Registro de: quem fez, o quê, quando e de qual origem (manual ou IA)
- Página de histórico de auditoria acessível ao usuário

---

### 🟡 F-06 — Datas e Prazos nos Itens

Permitir que o usuário associe uma data limite a cada item de tarefa.

- Campo de data de vencimento (due date) ao criar ou editar um item
- Destaque visual para itens vencidos ou próximos do vencimento
- Suporte ao Pajem para criar itens com prazo via linguagem natural (ex: "me lembra de pagar a conta até sexta")

---

### 🟡 F-07 — Prioridade nos Itens

O usuário poderá indicar o nível de urgência de cada item.

- Três níveis: baixa, média e alta
- Filtragem e ordenação por prioridade na visualização da lista
- Suporte ao Pajem para definir prioridade via linguagem natural

---

### 🟢 F-08 — Dashboard

Visão geral do estado atual das listas e tarefas do usuário.

- Quantidade de listas ativas
- Itens pendentes e concluídos (totais)
- Itens com prazo próximo ou vencidos
- Atividade recente (últimas ações realizadas)

---

### 🟢 F-09 — Busca e Filtros

Facilitar a navegação quando o usuário tiver muitas listas e itens.

- Busca por nome de lista ou item
- Filtro por status (pendente / concluído)
- Filtro por prioridade e data de vencimento

---

### 🟢 F-10 — Interface Responsiva

A aplicação deverá ser utilizável em dispositivos móveis.

- Layout adaptável para telas pequenas
- Interação com o Pajem acessível via mobile

---

### 🟡 F-11 — Barra de Progresso por Lista

Exibição visual do avanço de cada lista com base nos itens concluídos.

- Cálculo automático de `itens concluídos / total de itens`
- Barra de progresso exibida no card de cada lista
- Atualização em tempo real ao marcar/desmarcar itens (Turbo Streams)

---

### 🟡 F-12 — Cor Personalizada por Lista

O usuário poderá associar uma cor a cada lista para identificação visual rápida.

- Seletor de cor ao criar ou editar uma lista
- Cor aplicada ao card/header da lista na UI
- Suporte ao Pajem para criar listas com cor via linguagem natural (ex: "cria uma lista azul de compras")

---

### 🟡 F-13 — Contextos

O usuário poderá criar contextos (ex: Trabalho, Estudos, Casa) e associar cada lista a um contexto.

- `Context` é uma entidade própria: `user_id`, `name`
- Um usuário pode ter vários contextos
- Cada lista pode pertencer a um contexto (campo nullable — lista sem contexto é válida)
- Filtro por contexto na página de listas (ex: ver só as listas de "Trabalho")
- Ao excluir um contexto, as listas associadas ficam com `context_id: null` (sem cascata destrutiva)
- Suporte ao Pajem via tools `list_contexts`, `create_context` e `set_context`

---

### 🟡 F-14 — Soft Delete e Lixeira

Itens e listas excluídos não são removidos permanentemente do banco de dados. O usuário pode visualizá-los, restaurá-los ou apagá-los definitivamente.

- Campo `deleted_at` nas tabelas `lists` e `items`
- Registros com `deleted_at` preenchido são invisíveis na UI por default scope
- Aplicado tanto em exclusões manuais quanto via Pajem
- Contexto excluído não arrasta suas listas — listas ficam com `context_id: null`
- Página de lixeira onde o usuário visualiza listas e itens deletados
- Opção de restaurar um registro (zera o `deleted_at`)
- Opção de apagar permanentemente (hard delete) da lixeira — cumprindo o caminho de compliance GDPR

---

### 🟢 F-15 — Modo Escuro

Suporte a tema escuro na interface da aplicação.

- Alternância entre tema claro e escuro via toggle na navbar
- Preferência persistida no `localStorage` do navegador
- Implementado com CSS custom properties (sem dependência de biblioteca externa)

---

### 🟢 F-16 — Compartilhamento de Lista via Link Público

O usuário poderá gerar um link público read-only para compartilhar uma lista.

- Geração de token único (`share_token`) por lista
- Qualquer pessoa com o link pode visualizar a lista e seus itens sem login
- O usuário pode revogar o link a qualquer momento (regenerar ou desativar o token)
- Itens com soft delete não aparecem na view pública

---

### 🟢 F-17 — Desativação de Conta

O usuário poderá desativar sua própria conta sem perder os dados cadastrados.

- Opção de desativar conta nas configurações do perfil
- Conta desativada tem acesso bloqueado (redirecionada para login com mensagem informativa)
- Dados preservados no banco (`deleted_at` preenchido — soft delete)
- Opção de reativar a conta pelo próprio usuário (via e-mail de confirmação)
- Hard delete disponível mediante solicitação explícita — remove todos os dados permanentemente (GDPR)

---

## Stack Definida

| Componente     | Tecnologia           |
|----------------|----------------------|
| Backend        | Ruby on Rails        |
| Banco de dados | PostgreSQL           |
| IA / Assistente| A definir — provavelmente OpenAI (GPT) com tool use |
| Frontend       | Hotwire (Turbo + Stimulus) — padrão Rails |

---

## Observações Gerais

- A aplicação deve garantir que um usuário nunca acesse dados de outro usuário (isolamento por `user_id`)
- O Pajem deve operar exclusivamente sobre dados do usuário autenticado
- Ações destrutivas realizadas pelo Pajem devem sempre exigir confirmação
- Soft delete se aplica a listas e itens — exclusão de contexto não arrasta suas listas
- Links públicos (F-16) são a única exceção ao isolamento por autenticação — escopo read-only e limitado à lista compartilhada
- O tom da aplicação pode ser levemente temático (medieval/pajem), especialmente nas mensagens do assistente
