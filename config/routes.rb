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
    resources :items, path: "/itens", only: [ :show, :create, :edit, :update, :destroy ] do
      member do
        patch :toggle
      end
    end
  end

  namespace :pajem do
    resources :messages, path: "/mensagens", only: [ :create ]
  end

  get "/historico", to: "audit_logs#index", as: :audit_logs

  root to: "lists#index"
end
