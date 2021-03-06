Rails.application.routes.draw do
  
  resources :posts
  resources :visitors
  
  match '/contacts',     to: 'contacts#new',             via: 'get'
  match '/contacts',     to: 'contacts#create',          via: 'post'
  resources "contacts", only: [:new, :create]

  get 'posts/index'

  get 'posts/show'
  
  get 'products/:id', to: 'products#show', :as => :products

  resources :users
    
  resources :payments do
    member do
      get 'alice_step_1'
      get 'alice_step_11'
    end
  end
    
  resources :payment_requests do
    member do
      get 'bob_step_2'
      get 'complete'
      patch 'broadcast'
    end
  end
  
  root to: 'visitors#index'
  
  get '/auth/:provider/callback' => 'sessions#create'
  get '/signin' => 'sessions#new', :as => :signin
  get '/signout' => 'sessions#destroy', :as => :signout
  get '/auth/failure' => 'sessions#failure'
  
end
