# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '3.0'

Rails.application.config.assets.precompile += %w( plugins/owl.carousel.min.js )
Rails.application.config.assets.precompile += %w( plugins/jquery.peity.min.js )
Rails.application.config.assets.precompile += %w( plugins/jquery.waypoints.min.js )
Rails.application.config.assets.precompile += %w( plugins/smoothscroll.js )
Rails.application.config.assets.precompile += %w( plugins/wow.min.js )
Rails.application.config.assets.precompile += %w( custom.js )

Rails.application.config.assets.precompile += %w( scripts.js )

# Rails.application.config.assets.precompile += ['scripts.js']

