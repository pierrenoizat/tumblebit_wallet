Rails.application.routes.draw do
  
  devise_for :clients, controllers: { sessions: 'clients/sessions' }
  
  resources :posts
  resources :visitors
  
  match '/contacts',     to: 'contacts#new',             via: 'get'
  match '/contacts',     to: 'contacts#create',          via: 'post'
  resources "contacts", only: [:new, :create]
  
  resources :public_keys

  get 'posts/index'

  get 'posts/show'
  
  get 'products/:id', to: 'products#show', :as => :products

  resources :users
  resources :clients
  resources :puzzles do
    member do
      get 'create_blinding_factors'
      get 'tumbler_encrypts_values'
      get 'tumbler_checks_ro_values'
      get 'sender_checks_k_values'
    end
  end
  
  resources :scripts do
    resources :public_keys
      member do
        get 'create_spending_tx'
        get 'create_puzzle_z'
        patch 'sign_tx'
        patch 'broadcast'
      end
    end
  
  root to: 'visitors#index'
  
  get '/auth/:provider/callback' => 'sessions#create'
  get '/signin' => 'sessions#new', :as => :signin
  get '/signout' => 'sessions#destroy', :as => :signout
  get '/auth/failure' => 'sessions#failure'
  
end
