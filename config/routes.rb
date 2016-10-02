Rails.application.routes.draw do
  
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
  
  resources :scripts do
    resources :public_keys
      member do
        get 'display'
        get 'create_spending_tx'
        patch 'create_signed_transaction'
      end
    end
  
  root to: 'visitors#index'
  
  get '/auth/:provider/callback' => 'sessions#create'
  get '/signin' => 'sessions#new', :as => :signin
  get '/signout' => 'sessions#destroy', :as => :signout
  get '/auth/failure' => 'sessions#failure'
  
end
