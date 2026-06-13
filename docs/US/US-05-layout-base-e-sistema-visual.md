# US-05 — Layout Base e Sistema Visual

**Task de origem:** T-05  
**Depende de:** US-04 (T-04)  
**Features relacionadas:** F-15 (Modo Escuro), F-04 (Assistente Pajem — posicionamento)

---

## Contexto

Com a autenticação funcionando, esta US cria a estrutura visual da aplicação: o layout principal com barra superior e barra lateral, o sistema de cores baseado na identidade da v360 (roxo, laranja e branco), suporte a dark mode via CSS custom properties, o grid de listas em estilo post-it com expansão em tela cheia, e o widget flutuante do assistente Pajem no canto inferior direito. Nenhuma lógica de negócio é implementada aqui — apenas estrutura, estilo e comportamento visual.

---

## User Stories

**Como** usuário autenticado,  
**Quero** uma interface com identidade visual clara, barra de navegação, barra lateral e suporte a modo escuro,  
**Para que** eu possa navegar na aplicação de forma intuitiva e confortável em qualquer preferência de tema.

---

## Critérios de Aceitação

### 1. Paleta de cores — CSS Custom Properties

- [ ] Variáveis definidas em `app/assets/stylesheets/application.css` no seletor `:root` (modo claro)
- [ ] Variáveis de modo escuro no seletor `[data-theme="dark"]`
- [ ] Paleta do modo claro:

| Variável                  | Valor     | Uso                                      |
|---------------------------|-----------|------------------------------------------|
| `--color-primary`         | `#9633FF` | Roxo — cor principal da marca            |
| `--color-primary-light`   | `#B86AFF` | Roxo clareado — hover, destaques suaves  |
| `--color-primary-dark`    | `#6B1FCC` | Roxo escurecido — active, bordas         |
| `--color-secondary`       | `#FF5C13` | Laranja — ações secundárias, alertas     |
| `--color-secondary-light` | `#FF8A50` | Laranja clareado — hover                 |
| `--color-bg`              | `#FFFFFF` | Fundo principal                          |
| `--color-bg-surface`      | `#F5F0FF` | Fundo de cards e superfícies (roxo suave)|
| `--color-bg-sidebar`      | `#F0E8FF` | Fundo da sidebar                         |
| `--color-text`            | `#1A1A2E` | Texto principal                          |
| `--color-text-muted`      | `#6B6B8A` | Texto secundário                         |
| `--color-border`          | `#DDD0FF` | Bordas e divisores                       |
| `--color-topbar`          | `#9633FF` | Fundo da barra superior                  |
| `--color-topbar-text`     | `#FFFFFF` | Texto e ícones da barra superior         |

- [ ] Paleta do modo escuro (`[data-theme="dark"]`):

| Variável                  | Valor     |
|---------------------------|-----------|
| `--color-primary`         | `#B86AFF` |
| `--color-primary-light`   | `#CFA0FF` |
| `--color-primary-dark`    | `#9633FF` |
| `--color-secondary`       | `#FF7A3D` |
| `--color-secondary-light` | `#FFA070` |
| `--color-bg`              | `#0F0F1A` |
| `--color-bg-surface`      | `#1A1A2E` |
| `--color-bg-sidebar`      | `#16162A` |
| `--color-text`            | `#F0E8FF` |
| `--color-text-muted`      | `#9E8EBB` |
| `--color-border`          | `#2E2E4E` |
| `--color-topbar`          | `#16162A` |
| `--color-topbar-text`     | `#F0E8FF` |

### 2. Barra superior (topbar)

- [ ] Fixada no topo (`position: sticky; top: 0; z-index: 100`)
- [ ] Fundo `var(--color-topbar)`, texto `var(--color-topbar-text)`
- [ ] Altura via padding vertical — cresce conforme o conteúdo, sem valor fixo em px
- [ ] Conteúdo:
  - [ ] Logo / nome "Pajem" à esquerda
  - [ ] Toggle de dark mode à direita (ícone sol/lua)
  - [ ] Avatar ou nome do usuário logado à direita com link para configurações (rota futura: `/account` — renderizar como `href="#"` em T-05 até T-15 criar a rota)

### 3. Barra lateral (sidebar)

- [ ] Fundo `var(--color-bg-sidebar)`, borda direita `1px solid var(--color-border)`
- [ ] Largura definida via CSS custom property `--sidebar-width` (ajustável sem tocar no layout)
- [ ] Conteúdo:
  - [ ] Link para Dashboard com ícone — **placeholder em T-05**: renderizar como `href="#"` (Dashboard real implementado em T-13)
  - [ ] Separador
  - [ ] Seção "Listas":
    - [ ] Item "Todas as listas" (sem filtro de contexto)
    - [ ] Botão **"+ Nova Lista"** — link para `new_list_path` (**T-05**: renderizar como `href="#"` até T-07 criar a rota)
  - [ ] Separador
  - [ ] Seção "Contextos" — lista os contextos do usuário como filtros clicáveis (rota do filtro: `lists_path(context_id: context.id)` — **T-05**: `href="#"` até T-07)
    - [ ] Botão **"+ Novo Contexto"** — link para `new_context_path` (**T-05**: renderizar como `href="#"` até T-06 criar a rota)
  - [ ] Separador
  - [ ] Item "Lixeira" com ícone
- [ ] Item ativo destacado com `background: var(--color-primary)` e texto branco — detectado via helper `current_page?` do Rails ou comparação com `request.path`
- [ ] Contextos carregados via helper no layout (não requer Turbo aqui)

> **Nota:** A sidebar é fixa e não colapsável em T-05. Comportamento responsivo (menu hambúrguer, colapso em mobile) é escopo de T-16.

### 4. Área de conteúdo

- [ ] Ocupa o espaço restante após a sidebar (`flex: 1` ou `margin-inline-start: var(--sidebar-width)`)
- [ ] Padding interno consistente
- [ ] Fundo `var(--color-bg)`
- [ ] Flash messages exibidas no topo da área de conteúdo (dentro do `<main>`)
- [ ] Barra de ações no topo da área de conteúdo (abaixo das flash messages):
  - [ ] Botão **"Nova Lista"** em destaque — cor `var(--color-primary)`, visível em todas as páginas autenticadas (CTA principal da área de conteúdo; o botão "+ Nova Lista" da sidebar é um atalho compacto — ambos são intencionais)
  - [ ] Título da página atual (ex: "Todas as listas", "Trabalho", "Lixeira")

### 5. Grid de listas — estilo post-it

- [ ] Listas exibidas como cards em grid responsivo com `auto-fill` e tamanho mínimo relativo — sem largura fixa em px
- [ ] Cada post-it:
  - [ ] Fundo: cor da lista (`list.color`) se preenchida; caso contrário `var(--color-bg-surface)`
  - [ ] Borda superior destacada em `var(--color-primary)`
  - [ ] Sombra sutil com cor derivada da paleta primária
  - [ ] Cantos arredondados via `border-radius`
  - [ ] Exibe título, quantidade de itens pendentes e barra de progresso
  - [ ] Ícone de opções (editar, excluir) no canto superior direito
- [ ] Post-it clicável abre a lista em modo expandido (ver critério 6)

### 6. Lista expandida (modo tela cheia relativa)

- [ ] Ao clicar no post-it, a lista ocupa toda a área de conteúdo (entre topbar e sidebar)
- [ ] **Topbar e sidebar permanecem visíveis** — não é um modal sobre toda a tela
- [ ] Implementado com Stimulus: controller `list-expand` que alterna a classe `expanded` no elemento
- [ ] No estado `expanded`:
  - [ ] O grid de post-its fica oculto
  - [ ] A lista selecionada ocupa `width: 100%` e toda a altura disponível da área de conteúdo
  - [ ] Exibe título, descrição, barra de progresso e todos os itens
  - [ ] Botão **"+ Novo Item"** para adicionar tarefa à lista expandida
  - [ ] Botão **"Fechar"** retorna ao grid de post-its
- [ ] URL não muda (sem navegação — apenas estado visual via Stimulus)
- [ ] Os itens de cada lista são **pré-renderizados** no HTML inicial (ocultos via CSS) para que o Stimulus exiba sem request adicional — ver Notas Técnicas

### 7. Widget do assistente Pajem

- [ ] Botão flutuante fixado no canto inferior direito (`position: fixed; bottom: 0; right: 0` com padding via `safe-area-inset` para suporte a notch/home bar)
- [ ] Exibe foto estática do Pajem — placeholder PNG gerado no desenvolvimento (ver Notas Técnicas); **checkbox marcada com placeholder em vigor**, sem aguardar imagem final
- [ ] Foto circular com borda em `var(--color-secondary)` e sombra — tamanho via `clamp()` (CSS defensivo sem custo adicional; validação mobile não é escopo de T-05 — ver T-16)
- [ ] Ao clicar, abre o painel de chat acima do botão (estilo Facebook Messenger):
  - [ ] Painel ocupa largura proporcional à viewport (`min(90vw, 22rem)`) — cabe em mobile sem overflow
  - [ ] Altura máxima relativa à viewport (`max-height: 60vh`) com scroll interno na área de mensagens
  - [ ] Cabeçalho com nome "Pajem" e foto + botão de fechar (X)
  - [ ] Área de mensagens (scrollável)
  - [ ] Campo de input + botão enviar no rodapé
  - [ ] Fundo `var(--color-bg-surface)`, borda `1px solid var(--color-border)`
- [ ] Implementado com Stimulus: controller `pajem-chat` com método `toggle`
- [ ] Estado aberto/fechado **não** persiste entre page loads (abre sempre fechado)

### 8. Toggle de dark mode (Stimulus)

- [ ] Stimulus controller `theme` com método `toggle`
- [ ] Ao ativar: adiciona `data-theme="dark"` em `<html>`, salva `"dark"` no `localStorage`
- [ ] Ao desativar: remove o atributo, salva `"light"` no `localStorage`
- [ ] No carregamento da página: lê `localStorage` e aplica o tema antes do primeiro paint (script inline no `<head>` para evitar flash)

### 9. Flash messages

- [ ] Partial `app/views/shared/_flash.html.erb`
- [ ] Exibe `notice` (verde/roxo) e `alert` (laranja/vermelho)
- [ ] Auto-dismiss após 4 segundos via Stimulus controller `flash`
- [ ] Botão de fechar manual

---

## Estrutura de Arquivos

```
app/
  assets/
    stylesheets/
      application.css          ← variáveis CSS, reset, tipografia
      layout/
        topbar.css
        sidebar.css
        content.css
        postit.css
        pajem_widget.css
    images/
      pajem_avatar.png          ← placeholder (usuário fornece a imagem real)
  views/
    layouts/
      application.html.erb      ← estrutura principal
    shared/
      _topbar.html.erb
      _sidebar.html.erb
      _flash.html.erb
  javascript/
    controllers/
      theme_controller.js       ← dark mode toggle
      list_expand_controller.js ← expansão do post-it
      pajem_chat_controller.js  ← widget do assistente
      flash_controller.js       ← auto-dismiss flash
```

---

## Layout Estrutural

**Desktop** (sidebar expandida com labels):
```
┌──────────────────────────────────────────────────────┐
│  TOPBAR  [Logo Pajem]              [☀/🌙] [Avatar]  │
├────────────┬─────────────────────────────────────────┤
│            │                                         │
│  SIDEBAR   │  ÁREA DE CONTEÚDO                       │
│            │  (flash messages)                       │
│ Dashboard  │                                         │
│ ─────────  │  [post-it] [post-it] [post-it]          │
│ Contextos  │  [post-it] [post-it]                    │
│  • Trabalho│                                         │
│  • Casa    │                                         │
│ ─────────  │                                 [Pajem] │
│ Lixeira    │                              [chat popup│
│            │                               ao clicar]│
└────────────┴─────────────────────────────────────────┘
```



---

## Notas Técnicas

**Script de tema no `<head>` antes do CSS**  
Para evitar flash de tema errado no carregamento, inserir script inline mínimo antes do `<link>` do CSS:
```html
<script>
  if (localStorage.getItem('theme') === 'dark') {
    document.documentElement.setAttribute('data-theme', 'dark');
  }
</script>
```

**Post-it com cor customizada**  
A variável `list.color` é um hex `#RRGGBB`. Ao renderizar o card, aplicar via `style` inline:
```erb
style="background-color: <%= list.color.presence || 'var(--color-bg-surface)' %>;"
```
Garantir contraste do texto verificando se a cor é clara ou escura (lógica simples de luminância ou deixar sempre texto escuro no modo claro).

**`pajem_avatar.png` como placeholder**  
Criar um arquivo PNG quadrado de placeholder (círculo roxo com "P") para não bloquear o desenvolvimento. O usuário substituirá pela imagem real posteriormente. O CSS garante o formato circular via `border-radius: 50%` independente das dimensões da imagem.

**Sidebar com contextos**  
Os contextos são passados para o layout via `before_action` no `ApplicationController`:
```ruby
before_action :load_sidebar_data, if: :user_signed_in?

def load_sidebar_data
  @sidebar_contexts = current_user.contexts.order(:name)
end
```

**Controller stub e rota raiz em T-05**  
T-05 cria um `ListsController` com apenas a action `index` — suficiente para renderizar o grid com dados de seed. Não cria o CRUD completo (isso é T-07). A rota raiz aponta temporariamente para esse controller:

```ruby
root to: "lists#index"
```

Em T-07, o controller recebe CRUD completo. Em T-13, a rota raiz será atualizada para `dashboard#index`.

**`@lists` com itens pré-renderizados (critério 6)**  
Como a expansão do post-it é feita exclusivamente por Stimulus (sem request ao servidor), os itens de cada lista devem estar presentes no DOM desde o carregamento inicial — ocultos por CSS e revelados pelo controller ao expandir. O `index` carrega:

```ruby
def index
  @lists = current_user.lists.kept.includes(:items)
end
```

Cada card renderiza um `<div class="list-items hidden">` com os itens. O Stimulus remove `hidden` ao expandir e restaura ao fechar.

---

## Definition of Done

- [ ] CSS custom properties definidas para modo claro e escuro (incluindo `--color-secondary-light` em ambos os modos)
- [ ] Stub `ListsController#index` criado com `root to: "lists#index"` e `@lists = current_user.lists.kept.includes(:items)`
- [ ] Links sem rota em T-05 renderizados como `href="#"` (Dashboard, Nova Lista, Novo Contexto, Configurações)
- [ ] Topbar e sidebar renderizando em todas as páginas autenticadas
- [ ] Grid de post-its funcionando (sem dados reais — pode usar seeds ou fixtures)
- [ ] Expansão de post-it funcionando via Stimulus (topbar e sidebar permanecem visíveis)
- [ ] Widget do Pajem abrindo e fechando o painel de chat
- [ ] Toggle de dark mode funcionando com persistência no `localStorage` e sem flash no reload
- [ ] Flash messages com auto-dismiss
- [ ] Layout validado em desktop
- [ ] Código revisado e aprovado por ao menos um desenvolvedor
