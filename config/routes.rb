Rails.application.routes.draw do
  
  resources :users
  
  resources :trees do
      member do
        get 'display'
      end
    end
    
  
  resources :leaf_nodes
  resources :nodes
  
  root to: 'visitors#index'
  
  get '/auth/:provider/callback' => 'sessions#create'
  get '/signin' => 'sessions#new', :as => :signin
  get '/signout' => 'sessions#destroy', :as => :signout
  get '/auth/failure' => 'sessions#failure'
  
  mount Resque::Server, :at => "/resque"
  
end
