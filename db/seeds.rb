# Seeds de demonstração — dados para visualizar a UI completa

user = User.find_or_create_by!(email: "demo@pajem.dev") do |u|
  u.name     = "Demo User"
  u.password = "123456789"
  u.password_confirmation = "123456789"
end

hoje = Date.current

trabalho = Context.find_or_create_by!(name: "Trabalho", user: user)
casa     = Context.find_or_create_by!(name: "Casa",     user: user)
pessoal  = Context.find_or_create_by!(name: "Pessoal",  user: user)

lists_data = [
  {
    title:       "Sprint Atual",
    description: "Tarefas do sprint em andamento",
    context:     trabalho,
    color:       "#DCEDC8",
    items: [
      { title: "Implementar autenticação",     completed: true,  priority: :high,   due_date: hoje - 5, description: "Devise + confirmação por e-mail" },
      { title: "Criar layout base (US-05)",    completed: true,  priority: :high,   due_date: hoje - 2 },
      { title: "Grid de post-its",             completed: false, priority: :high,   due_date: hoje,     description: "Dashboard com cards por lista" },
      { title: "Widget do Pajem",              completed: false, priority: :medium, due_date: hoje + 3 },
      { title: "Corrigir bug de cache",        completed: false, priority: :high,   due_date: hoje - 1, description: "SolidCache incompatível com delete_matched" },
      { title: "Testes de integração do CRUD", completed: false, priority: :medium, due_date: hoje + 5 }
    ]
  },
  {
    title:       "Backlog do Produto",
    description: "Funcionalidades planejadas para próximas sprints",
    context:     trabalho,
    color:       nil,
    items: [
      { title: "Sistema de busca global",          completed: false, priority: :medium, due_date: hoje + 14 },
      { title: "Integração com calendário",        completed: false, priority: :low,    due_date: nil,       description: "Google Calendar ou iCal" },
      { title: "Notificações push",                completed: false, priority: :low },
      { title: "Filtro por prioridade e contexto", completed: false, priority: :medium, due_date: hoje + 7 },
      { title: "Exportar listas como CSV",         completed: false, priority: :low }
    ]
  },
  {
    title:       "Compras",
    description: "Lista da semana",
    context:     casa,
    color:       "#FFF9C4",
    items: [
      { title: "Pão e leite",     completed: true,  priority: :low,    due_date: hoje - 1 },
      { title: "Frutas da época", completed: false, priority: :medium, due_date: hoje },
      { title: "Sabão em pó",     completed: false, priority: :low,    due_date: hoje + 2 },
      { title: "Óleo de cozinha", completed: false, priority: :low },
      { title: "Detergente",      completed: false, priority: :low }
    ]
  },
  {
    title:       "Leituras",
    description: "Livros e artigos na fila",
    context:     pessoal,
    color:       "#BBDEFB",
    items: [
      { title: "The Pragmatic Programmer", completed: true,  priority: :high,   description: "Hunt & Thomas — foco nos capítulos de automação" },
      { title: "Clean Architecture",       completed: false, priority: :high,   due_date: hoje + 21, description: "Robert C. Martin" },
      { title: "Inspired",                 completed: false, priority: :medium, description: "Marty Cagan — product management" },
      { title: "Shape Up",                 completed: false, priority: :medium, description: "Basecamp — metodologia de produto" }
    ]
  },
  {
    title:       "Ideias & Inspiração",
    description: nil,
    context:     nil,
    color:       "#FFE0B2",
    items: [
      { title: "Dashboard com IA",          completed: false, priority: :medium, description: "Resumo automático das tarefas do dia via Claude" },
      { title: "Modo offline (PWA)",        completed: false, priority: :low },
      { title: "Tema escuro",               completed: false, priority: :low,    due_date: hoje + 10 },
      { title: "App mobile com Turbo Native", completed: false, priority: :medium }
    ]
  }
]

lists_data.each do |attrs|
  items = attrs.delete(:items)

  list = List.find_or_create_by!(title: attrs[:title], user: user) do |l|
    l.description = attrs[:description]
    l.context     = attrs[:context]
    l.color       = attrs[:color]
  end

  next if list.items.exists?

  items.each do |item_attrs|
    list.items.create!(
      title:       item_attrs[:title],
      description: item_attrs[:description],
      completed:   item_attrs[:completed],
      priority:    item_attrs[:priority],
      due_date:    item_attrs[:due_date],
      user:        user
    )
  end
end

puts "Seeds criados: #{user.email} / 123456789"
puts "  #{user.contexts.count} contextos, #{user.lists.count} listas, #{user.items.count} itens"
