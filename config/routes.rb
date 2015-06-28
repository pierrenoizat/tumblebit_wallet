Rails.application.routes.draw do
  
  resources :posts
  
  match '/contacts',     to: 'contacts#new',             via: 'get'
  resources "contacts", only: [:new, :create]
  
  # resources :products

  get 'posts/index'

  get 'posts/show'
  
  get "trees/download_wp"
  
  get 'products/:id', to: 'products#show', :as => :products

  resources :users
  
  resources :trees do
      member do
        get 'display'
        get 'download_json'
        post 'upload_json'
      end
    end
    
  resources :leaf_nodes do
    member do
      get 'display'
    end
  end
    
  resources :nodes
  
  root to: 'visitors#index'
  
  get '/auth/:provider/callback' => 'sessions#create'
  get '/signin' => 'sessions#new', :as => :signin
  get '/signout' => 'sessions#destroy', :as => :signout
  get '/auth/failure' => 'sessions#failure'
  
  mount Resque::Server, :at => "/resque"
  
end
