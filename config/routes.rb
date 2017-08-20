Rails.application.routes.draw do
  
  devise_for :clients, controllers: { sessions: 'clients/sessions' }
  
  resources :posts
  resources :visitors
  
  match '/contacts',     to: 'contacts#new',             via: 'get'
  match '/contacts',     to: 'contacts#create',          via: 'post'
  resources "contacts", only: [:new, :create]

  get 'posts/index'

  get 'posts/show'
  
  get 'products/:id', to: 'products#show', :as => :products

  resources :users
  resources :clients
    
  resources :payments do
    member do
      get 'alice_step_1'
      get 'alice_step_5'
      get 'alice_step_7'
      get 'alice_step_11'
      get 'bob_step_8'
      get 'bob_step_10'
      get 'tumbler_encrypts_values'
      get 'tumbler_checks_ro_values'
      get 'bob_gets_sigma'
    end
  end
    
  resources :payment_requests do
    member do
      get 'bob_step_2'
      get 'complete'
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
