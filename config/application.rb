require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Tumblebit
  class Application < Rails::Application
    
    config.autoload_paths += %W(#{config.root}/lib) # add this line

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
    $BLOCKR_ADDRESS_UNCONFIRMED_URL ="http://btc.blockr.io/api/v1/address/unconfirmed/"
    $BLOCKR_RAW_TX_URL = "http://btc.blockr.io/api/v1/tx/raw/"
    $BLOCKCHAIN_UTXO_URL = "https://blockchain.info/unspent?active="
    $BLOCKCHAIN_RAW_TX_URL = "https://blockchain.info/rawtx/"
    $TUMBLER_RSA_PUBLIC_EXPONENT = 0x10001
    $TUMBLER_RSA_PUBLIC_KEY = 0xcd0b9724a2a09b16d7739bc9daa29274563765110ba93a2f8f880ce9191909050599ee361eadec462e7c9b167aa020d61c93d6787921242c76a8cfd7c29ec5fe626e36ed06134ffc37fe3638dff132be1f15ed0fa43c3d957436b67ef42a1bb58f6154f30e5b30e7048bbff83375ae666900808558269c30d297190883d83bf1
    $FEE_RATE = 200.0 # sat/byte
    # $TUMBLER_COLLECTION_ADDRESS = "1LnEtnWKC5PyJQ7bJ8Y33c1rgzChkVmvKW" # wif : "L2dSPKfm998jApkYyF1CoM5zR6rYAassuSbgagMkyB8vxfpiEzFU"
    $BOB_PAYOUT_ADDRESS = "1Axoqagyjn5RXcNyLP144dzzYUppTKkB6L" # wif : "L4Pny7E44175jXdStRiHkn8cESPpxMmUNc4WsMPFtFi3em89kotK"
    # $PAYMENT_UPDATE_API_URL ="http://0.0.0.0:3000/api/v1/payment"
    $TUMBLER_PAYMENT_API_URL = "https://fierce-ocean-41496.herokuapp.com/api/v1/payment"
    $TUMBLER_PAYMENT_REQUEST_API_URL = "https://fierce-ocean-41496.herokuapp.com/api/v1/payment_request"
    # $AES_INIT_VECTOR = "6be1e1c3469e5538a7cc29ef6b9806af"  # not a secret !
    $AES_INIT_VECTOR = "d67194ad7420938b74d164738daf274f84f9eb33b304186df4f1b8fd73a21219" # TODO dynamic generation with each encryption
  end
end
