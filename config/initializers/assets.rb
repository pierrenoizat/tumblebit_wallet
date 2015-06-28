# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )



Rails.application.config.assets.precompile += %w( plugins/owl.carousel.min.js )
Rails.application.config.assets.precompile += %w( plugins/jquery.peity.min.js )
Rails.application.config.assets.precompile += %w( plugins/jquery.waypoints.min.js )
Rails.application.config.assets.precompile += %w( plugins/smoothscroll.js )
Rails.application.config.assets.precompile += %w( plugins/wow.min.js )
Rails.application.config.assets.precompile += %w( plugins/contact.js )
# Rails.application.config.assets.precompile += %w( plugins/lightbox.min.js )
Rails.application.config.assets.precompile += %w( bootstrap/bootstrap.min.js )
Rails.application.config.assets.precompile += %w( custom.js )

Rails.application.config.assets.precompile += %w( open-iconic/font/css/open-iconic-bootstrap.css )
Rails.application.config.assets.precompile += %w( font-awesome/css/font-awesome.min.css )
# Rails.application.config.assets.precompile += %w( plugins/lightbox.css )
Rails.application.config.assets.precompile += %w( plugins/animate.css )
Rails.application.config.assets.precompile += %w( plugins/owl.carousel.css )
Rails.application.config.assets.precompile += %w( styles.css )