Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  
  # Uncomment this to test e-mails in development mode
   config.action_mailer.delivery_method = :smtp

  config.action_mailer.smtp_settings = {
    :address => "smtp.gmail.com",
    :port => 587,
    :domain => "google.com",
    :authentication => "plain",
    :user_name => "hashtrees", # email will be sent from hashtrees@gmail.com
    :password => Figaro.env.mail_password,
    :enable_starttls_auto  => true # changed from true 27 april 2013
  }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true


  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  
  $MAIN_URL = "http://localhost:3000"
  $TREES_URL = "http://localhost:3000/trees/"
  $LEAF_NODES_URL = "http://localhost:3000/leaf_nodes/" 
  
  if File.exists?("app/assets/tree_17.csv")
    File.delete("app/assets/tree_17.csv") # delete any previous version of "app/assets/tree_8193.csv" file
    end
  
  require "csv"
  CSV.open("app/assets/tree_17.csv", "ab") do |csv| # output users and their balance to tree_17.csv file
    for i in 1..17 do
      string = Faker::Number.number(4).to_s + rand.to_s
      sum = string.to_f/1000
      csv << ["#{Faker::Internet.email}","#{sum}"]
    end
  end # of CSV write to tree_17.csv
  
  config.paperclip_defaults = {
    :storage => :s3,
    :s3_protocol => 'http',
    :s3_credentials => {
      :bucket => 'hashtree-test'
    }
  }
  
end
