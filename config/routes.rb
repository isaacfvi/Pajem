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
  resources :lists, only: [ :index ]

  root to: "lists#index"
end
