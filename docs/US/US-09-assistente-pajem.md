# US-09 — Assistente Pajem

**Task de origem:** T-09  
**Depende de:** US-08 (T-08)  
**Features relacionadas:** F-04 (Assistente de IA "Pajem")

---

## Contexto

O Pajem é um assistente com loop agêntico que interpreta comandos em linguagem natural e executa ações sobre os dados do usuário. As **tools são métodos Ruby** da aplicação (`create_list`, `complete_item`, etc.) — o LLM nunca executa código diretamente. Ele apenas declara quais tools quer chamar e com quais parâmetros; o Rails executa os métodos correspondentes, devolve os resultados, e o LLM formula a resposta final.

O fluxo passa por três prompts em sequência: guardrails → loop agêntico → resposta final. Ações destrutivas (`delete_list`, `delete_item`) têm um passo extra de confirmação entre o loop e a resposta final.

> **Decisão pendente:** provedor de LLM a definir. A arquitetura de serviços deve isolar o provedor para permitir troca sem alterar o restante da aplicação.

---

## User Stories

**Como** usuário autenticado,  
**Quero** digitar comandos em linguagem natural no chat do Pajem,  
**Para que** ele execute ações nas minhas listas e itens sem eu precisar navegar pelos formulários.

---

## Fluxo Principal

### Sem ação destrutiva

```
Mensagem do usuário
       ↓
  [1. Guardrails]
  Fora do escopo? → Responde diretamente e encerra
       ↓ (dentro do escopo)
  [2. Loop agêntico]
  Prompt com lista de tools disponíveis
  LLM retorna: tools que quer chamar + parâmetros
  Rails executa os métodos Ruby e coleta resultados
  Repete até LLM não solicitar mais tools
       ↓
  [3. Resposta final]
  Prompt com resultados das tools
  LLM formata resposta em linguagem natural (tom medieval)
       ↓
  Exibe ao usuário via Turbo Stream
```

### Com ação destrutiva (`delete_list` ou `delete_item`)

```
  [2. Loop agêntico] — LLM solicita delete_list ou delete_item
       ↓
  Rails NÃO executa — serializa a ação pendente em metadata
       ↓
  [3a. Confirmação]
  LLM formula pergunta de confirmação em linguagem natural
  Exibe ao usuário e aguarda próxima mensagem
       ↓
  Usuário confirma → executa o método Ruby → [3. Resposta final]
  Usuário nega    → descarta ação pendente → [3. Resposta final]
```

---

## Critérios de Aceitação

### 1. Posicionamento do widget

- [ ] Widget reposicionado para o **canto inferior esquerdo** — ajuste de CSS sobre o layout entregue em US-05 (`right` → `left`)
- [ ] Painel de chat abre à esquerda, acima do botão, sem sobrepor a sidebar

### 2. Interface de chat (widget)

- [ ] Formulário no widget do Pajem envia mensagem via `POST /pajem/mensagens`
- [ ] Resposta exibida via Turbo Stream — sem reload de página
- [ ] Histórico de mensagens da sessão exibido no painel (`user` e `assistant` diferenciados visualmente)
- [ ] Campo de input limpo após envio
- [ ] Enquanto o Pajem processa: indicador de carregamento ("Pajem está pensando...")
- [ ] Erro de API exibe mensagem amigável — sem expor detalhes técnicos ao usuário

### 3. Persistência de mensagens

- [ ] Mensagem do usuário e resposta final do Pajem salvas em `chat_messages` com `user_id`, `role` e `content`
- [ ] Resultados intermediários das tools **não** são persistidos — apenas mantidos em memória durante o loop
- [ ] Ação destrutiva pendente serializada em `metadata` da mensagem do assistente:
  ```json
  { "pending_confirmation": { "tool": "delete_list", "params": { "list_id": 42 } } }
  ```

### 4. Prompt 1 — Guardrails (`Pajem::Guardrails`)

- [ ] Recebe a mensagem do usuário e verifica se está dentro do escopo da aplicação (listas, itens, contextos)
- [ ] Se fora do escopo: responde diretamente com mensagem de recusa em tom medieval e encerra — **sem chamar o loop**
- [ ] Se dentro do escopo: passa para o loop agêntico
- [ ] Exemplos de recusa: pedidos de código, perguntas gerais, conteúdo ofensivo

### 5. Prompt 2 — Loop agêntico (`Pajem::Assistant`)

- [ ] Prompt inclui a lista de tools disponíveis como schema JSON (`Pajem::ToolDefinitions`)
- [ ] LLM retorna quais tools quer chamar e com quais parâmetros — **não executa nada**
- [ ] Rails executa os métodos Ruby correspondentes em `Pajem::Tools`, scoped ao `current_user`
- [ ] Resultado de cada tool é devolvido ao LLM na próxima iteração
- [ ] Loop repete até LLM não solicitar mais tools ou atingir limite de 10 iterações
- [ ] Se `delete_list` ou `delete_item` for solicitada: **interrompe o loop**, serializa a ação e vai para confirmação
- [ ] Parâmetro inválido ou recurso inexistente: tool retorna erro descritivo, LLM decide se tenta novamente ou encerra

### 6. Tools disponíveis (`Pajem::Tools`)

Cada tool é um método Ruby que recebe `user:` e parâmetros específicos, executa a ação e retorna `{ success:, message: }`.

| Tool              | Parâmetros                                                        | Ação                            |
|-------------------|-------------------------------------------------------------------|---------------------------------|
| `list_lists`      | `context_id` (opcional)                                           | Retorna listas ativas           |
| `list_items`      | `list_id`                                                         | Retorna itens ativos de uma lista |
| `list_contexts`   | —                                                                 | Retorna contextos do usuário    |
| `create_list`     | `title`, `color` (opcional), `context_id` (opcional)             | Cria lista                      |
| `create_item`     | `list_id`, `title`, `due_date` (opcional), `priority` (opcional) | Cria item                       |
| `create_context`  | `name`                                                            | Cria contexto                   |
| `set_context`     | `list_id`, `context_id`                                           | Associa lista a um contexto     |
| `complete_item`   | `item_id`                                                         | Marca item como concluído       |
| `uncomplete_item` | `item_id`                                                         | Desmarca item como concluído    |
| `delete_list`     | `list_id`                                                         | **Requer confirmação**          |
| `delete_item`     | `item_id`                                                         | **Requer confirmação**          |

### 7. Prompt 3a — Confirmação de ações destrutivas

- [ ] LLM recebe a ação pendente serializada e formula pergunta de confirmação em linguagem natural
- [ ] Exemplo: *"Tens certeza que queres excluir a lista 'Compras'? Responde 'sim' para confirmar ou 'não' para cancelar."*
- [ ] Na próxima mensagem do usuário: LLM interpreta se é confirmação ou negação
- [ ] Confirmação → Rails executa o método Ruby de delete → vai para resposta final
- [ ] Negação → ação descartada → vai para resposta final informando o cancelamento

### 8. Prompt 3 — Resposta final (`Pajem::Responder`)

- [ ] Recebe os resultados das tools e formata a resposta em linguagem natural
- [ ] Tom levemente medieval/cortesão — claro e útil acima de tudo
- [ ] Exemplos: *"Às suas ordens — a lista foi criada."*, *"O item foi concluído."*

### 9. Audit log

- [ ] Toda tool executada com sucesso chama `AuditLog.record` com `origin: "assistant"`
- [ ] Ações canceladas na confirmação **não** geram audit log

### 10. Testes

- [ ] `Pajem::GuardrailsTest`: mensagem dentro do escopo passa; mensagem fora do escopo retorna recusa
- [ ] `Pajem::ToolsTest`: cada tool com input válido, inválido e recurso de outro usuário
- [ ] `Pajem::AssistantTest`: loop com mock do LLM — sem tools, com tools, com delete interrompendo o loop, limite de iterações
- [ ] `PajemControllerTest`: `POST /pajem/mensagens` salva mensagem, retorna Turbo Stream, rejeita sem autenticação

---

## Rotas

```ruby
namespace :pajem do
  resources :messages, path: "/mensagens", only: [:create]
end
```

---

## Estrutura de Serviços

```
app/
  services/
    pajem/
      guardrails.rb       ← prompt 1: filtra escopo
      assistant.rb        ← prompt 2: loop agêntico
      tools.rb            ← métodos Ruby executados pelo loop
      tool_definitions.rb ← schemas JSON enviados ao LLM
      responder.rb        ← prompt 3: formata resposta final
  controllers/
    pajem/
      messages_controller.rb
```

---

## Notas Técnicas

**Tools são métodos Ruby — o LLM só declara**  
O LLM recebe os schemas JSON das tools e retorna algo como `{ "tool": "create_list", "params": { "title": "Compras" } }`. O Rails lê isso, chama `Pajem::Tools.create_list(user: current_user, title: "Compras")` e devolve o resultado ao LLM. O LLM nunca toca no banco.

**Isolamento do provedor**  
O `Pajem::Assistant` chama o LLM via `Pajem::LLMClient` — adaptador isolado. Trocar de provedor significa alterar apenas esse arquivo.

**Limite de 10 iterações**  
Evita loop infinito caso o LLM fique preso solicitando tools repetidamente. Ao atingir o limite, o Pajem responde com *"Não consegui completar o teu pedido. Podes tentar de outra forma?"* e encerra.

**Histórico de mensagens no contexto**  
O loop recebe as últimas N mensagens persistidas em `chat_messages` para manter contexto da conversa. Mensagem com `pending_confirmation` no `metadata` é incluída para o LLM saber que há uma ação aguardando resposta.

---

## Decisões Técnicas

### Provedor LLM: Groq via HTTP bruto

Gemini (opção inicial) foi descartado por atingir cota diária gratuita com rapidez. Groq foi escolhido pelo plano free generoso e suporte a tool calling. A integração usa `Net::HTTP` diretamente — sem gem de SDK — porque o contrato da API é simples (compatível com OpenAI) e adicionar uma dependência apenas para um endpoint seria excesso.

O provider está em `Pajem::Providers::Groq` e é injetado via `Pajem::LLMClient`. Trocar de provedor significa criar um novo arquivo em `providers/` e atualizar o default no construtor do `LLMClient`.

**Modelo atual:** `llama-3.3-70b-versatile`.

---

### Formato normalizado de resposta do LLM

O provider retorna um hash normalizado `{ content: String, tool_calls: Array }`, independente do formato bruto da API. O restante da aplicação nunca toca na resposta HTTP diretamente.

---

### `parallel_tool_calls: false`

O Groq permite que o modelo emita múltiplas tool calls numa mesma resposta. Na prática, o modelo tentava encadear `list_lists` como argumento de `create_item` — gerando JSON inválido e erro 400. Desabilitar chamadas paralelas força o modelo a uma tool por iteração, eliminando o problema.

---

### Schema de tools: campos de ID sem `type`

O Groq valida os parâmetros da tool call contra o schema JSON antes de devolver a resposta. O modelo ora emitia IDs como inteiro, ora como string — e qualquer `type` fixo causava erro 400 para metade dos casos. A solução foi omitir `type` nos campos de ID, delegando a coerção ao Ruby (`.to_i` já presente em todos os métodos de `Pajem::Tools`).

---

### Guardrails com lógica invertida

Em vez de listar o que está dentro do escopo, o prompt de guardrails enumera apenas os casos que claramente estão fora (trivia, piadas, cálculos matemáticos puros, conteúdo ofensivo). Qualquer dúvida é classificada como dentro do escopo. Isso evita falsos negativos em mensagens ambíguas — como realizações pessoais ("finalizei meu dashboard") ou ideias ("tive uma ideia de escrever uma campanha de RPG") — que são candidatas a virar itens de lista.

---

### Personalidade do Pajem (Responder)

O `Responder` adota a persona de aprendiz fiel de um mago sábio: prestativo, ligeiramente solene, mas direto. Não menciona IDs, nomes de tools ou etapas técnicas — apenas o resultado. Tom definido via exemplos concretos no system prompt.

---

### Turbo Broadcastable manual (sem macro)

A macro `broadcasts_to` do turbo-rails não permite customização do comportamento de soft delete. Como `Item`, `List` e `Context` usam `Discard` (soft delete via `deleted_at`), o broadcast de remoção precisa ser disparado em `after_update_commit` detectando `saved_change_to_deleted_at?` — impossível com a macro. Todos os broadcasts são implementados manualmente com `broadcast_append_to`, `broadcast_replace_to` e `broadcast_remove_to`.

---

### `ActionView::RecordIdentifier` no `ApplicationRecord`

O helper `dom_id` é necessário nos callbacks de broadcast dos models, mas não estava disponível no escopo de instância mesmo com turbo-rails carregado. Solução: `include ActionView::RecordIdentifier` no `ApplicationRecord`, tornando `dom_id` disponível em todos os models.

---

### `build_summary`: filtragem de resultados intermediários

O `MessagesController` acumula todos os resultados de tools durante o loop e os envia ao `Responder`. Se o modelo tentou uma ação que falhou e depois conseguiu na iteração seguinte, ambas as mensagens apareciam na resposta final — gerando texto confuso ("não encontrei a lista com ID X, mas encontrei a 'Compras'"). O `build_summary` agora filtra: resultados de lookup (`list_lists`, `list_items`, `list_contexts`) e falhas intermediárias são descartados quando ao menos uma ação de escrita teve sucesso.

---

### Animação de fechamento do chat: CSS transition em vez de View Transition

A View Transition API causa conflito visual quando uma lista está expandida — a animação do `pajem-panel` interfere com a do `active-card`. O fechamento do chat usa CSS transition diretamente (opacidade + escala + `data-closing`), evitando o conflito. A abertura ainda usa View Transition, mas apenas quando não há lista expandida (`document.querySelector(".lists-page--expanded")`).

---

## Definition of Done

- [ ] Três prompts implementados: guardrails, loop agêntico e resposta final
- [ ] Todas as 11 tools implementadas e scoped por `current_user`
- [ ] Fluxo de confirmação para `delete_list` e `delete_item` funcionando
- [ ] Mensagens persistidas em `chat_messages`
- [ ] Audit log com `origin: "assistant"` em todas as ações executadas
- [ ] Interface de chat respondendo via Turbo Stream sem reload
- [ ] Widget posicionado no canto inferior esquerdo
- [ ] `bundle exec rails test test/services/pajem` e `test/controllers/pajem` verdes
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
