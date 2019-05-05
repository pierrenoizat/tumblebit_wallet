require File.expand_path('../boot', __FILE__)

require 'rails/all'

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
    $TUMBLER_COLLECTION_ADDRESS = "1LnEtnWKC5PyJQ7bJ8Y33c1rgzChkVmvKW"
    $BOB_PAYOUT_ADDRESS = "1Axoqagyjn5RXcNyLP144dzzYUppTKkB6L"
    $TUMBLER_PAYMENT_API_URL = "https://tumblebit.network/api/v1/payment"
    $TUMBLER_PAYMENT_REQUEST_API_URL = "https://tumblebit.network/api/v1/payment_request"
    $AES_INIT_VECTOR = "d67194ad7420938b74d164738daf274f84f9eb33b304186df4f1b8fd73a21219" # not a secret ! TODO dynamic generation with each encryption
  end
end
