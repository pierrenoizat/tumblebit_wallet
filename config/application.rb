require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsOmniauth
  class Application < Rails::Application

    config.generators do |g|
      g.test_framework :rspec,
        fixtures: true,
        view_specs: false,
        helper_specs: false,
        routing_specs: false,
        controller_specs: false,
        request_specs: false
      g.fixture_replacement :factory_girl, dir: "spec/factories"
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true
    $SALT_STRING = "ygiu1211095gadqfzzieczc4320098777pmlkjuyrcw67xfxuxgwosjdhdhd76392187643hdhsdndiidnd"
    
    $BLOCKR_ADDRESS_UNSPENT_URL = "http://btc.blockr.io/api/v1/address/unspent/"
    $BLOCKR_ADDRESS_BALANCE_URL = "http://btc.blockr.io/api/v1/address/info/"
    
    $BLOCKCHAIN_ADDRESS_BALANCE_URL = "https://blockchain.info/fr/address/"
    
    $PUSH_TX_URL = "https://api.blockcypher.com/v1/btc/main/txs/push"
    
    $BLOCKR_ADDRESS_TXS_URL ="http://btc.blockr.io/api/v1/address/txs/"

    $TUMBLER_RSA_PUBLIC_EXPONENT = 0x10001
    $TUMBLER_RSA_PUBLIC_KEY=0xcd0b9724a2a09b16d7739bc9daa29274563765110ba93a2f8f880ce9191909050599ee361eadec462e7c9b167aa020d61c93d6787921242c76a8cfd7c29ec5fe626e36ed06134ffc37fe3638dff132be1f15ed0fa43c3d957436b67ef42a1bb58f6154f30e5b30e7048bbff83375ae666900808558269c30d297190883d83bf1
    
  end
end
