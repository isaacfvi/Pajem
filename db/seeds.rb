# Seeds de desenvolvimento — dados para visualizar a UI da US-05

user = User.find_or_create_by!(email: "demo@pajem.dev") do |u|
  u.name     = "Demo User"
  u.password = "123456789"
  u.password_confirmation = "123456789"
end

trabalho  = Context.find_or_create_by!(name: "Trabalho",  user: user)
casa      = Context.find_or_create_by!(name: "Casa",      user: user)
pessoal   = Context.find_or_create_by!(name: "Pessoal",   user: user)

lists_data = [
  { title: "Sprint Atual",        context: trabalho, color: "#C8E6C9" },
  { title: "Backlog do Produto",  context: trabalho, color: nil },
  { title: "Compras",             context: casa,     color: "#FFF9C4" },
  { title: "Leituras",            context: pessoal,  color: nil },
  { title: "Ideias & Inspiração", context: nil,      color: "#FFE0B2" },
]

lists_data.each do |attrs|
  list = List.find_or_create_by!(title: attrs[:title], user: user) do |l|
    l.context = attrs[:context]
    l.color   = attrs[:color]
  end

  next if list.items.exists?

  case list.title
  when "Sprint Atual"
    [ [ "Implementar autenticação",    true  ],
      [ "Criar layout base (US-05)",   false ],
      [ "Grid de post-its",            false ],
      [ "Widget do Pajem",             false ] ].each do |(title, done)|
      list.items.create!(title: title, completed: done, user: user)
    end
  when "Backlog do Produto"
    [ "Sistema de busca", "Integração com calendário", "Notificações push" ].each do |t|
      list.items.create!(title: t, completed: false, user: user)
    end
  when "Compras"
    [ [ "Pão e leite",    true  ],
      [ "Frutas da época", false ],
      [ "Sabão em pó",    false ] ].each do |(title, done)|
      list.items.create!(title: title, completed: done, user: user)
    end
  when "Leituras"
    [ "The Pragmatic Programmer", "Clean Architecture", "Inspired" ].each do |t|
      list.items.create!(title: t, completed: false, user: user)
    end
  when "Ideias & Inspiração"
    [ "Dashboard com IA", "Modo offline (PWA)" ].each do |t|
      list.items.create!(title: t, completed: false, user: user)
    end
  end
end

puts "Seeds criados: #{user.email} / 123456789"
puts "  #{user.contexts.count} contextos, #{user.lists.count} listas, #{user.items.count} itens"
