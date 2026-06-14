Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get    "/signup",            to: "registrations#new",     as: :signup
  post   "/signup",            to: "registrations#create"

  get    "/login",             to: "sessions#new",          as: :login
  post   "/login",             to: "sessions#create"
  delete "/logout",            to: "sessions#destroy",      as: :logout

  get    "/password/forgot",   to: "password_resets#new",   as: :forgot_password
  post   "/password/forgot",   to: "password_resets#create"
  get    "/password/reset",    to: "password_resets#edit",  as: :reset_password
  patch  "/password/reset",    to: "password_resets#update"

  resources :contexts, path: "/contextos", only: [ :new, :create, :edit, :update, :destroy ]
  resources :lists, path: "/listas", only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member do
      patch :compartilhar
      patch :revogar_link
    end
    resources :items, path: "/itens", only: [ :index, :show, :create, :edit, :update, :destroy ] do
      member do
        patch :toggle
      end
    end
  end

  get "/c/:token", to: "shares#show", as: :share

  namespace :pajem do
    resources :messages, path: "/mensagens", only: [ :create ]
  end

  resource :conta, only: [ :show, :update, :destroy ], path: "/conta", controller: "accounts" do
    collection do
      get  "reativar/reenviar", to: "accounts#reactivation_form",   as: :reactivation_form
      post "reativar/reenviar", to: "accounts#resend_reactivation",  as: :resend_reactivation
      get  "reativar/:token",   to: "accounts#reactivate",           as: :reactivate
    end
  end

  get "/historico", to: "audit_logs#index", as: :audit_logs

  get    "/lixeira",                       to: "trash#index",        as: :trash
  patch  "/lixeira/listas/:id/restaurar",  to: "trash#restore_list", as: :restore_trash_list
  delete "/lixeira/listas/:id",            to: "trash#destroy_list", as: :trash_list
  patch  "/lixeira/itens/:id/restaurar",   to: "trash#restore_item", as: :restore_trash_item
  delete "/lixeira/itens/:id",             to: "trash#destroy_item", as: :trash_item

  root to: "dashboard#index"
end
