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
    
    $PUSH_TX_URL = "https://api.blockcypher.com/v1/btc/main/txs/push"
    
    $BLOCKR_ADDRESS_TXS_URL ="http://btc.blockr.io/api/v1/address/txs/"
    
    "http://btc.blockr.io/api/v1/address/unspent/" #  ?unconfirmed=1
    
    $TUMBLER_RSA_PUBLIC_KEY="MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnGyt+yEPqJXudkpKrYT4\nA7s5NCprMnu58EUd/8qMZDX2XfqKN67fG0iHrI62gi5ApOE/sM6fY3pZUXQHLuDh\nSgqJ0uaOgzF9f2xDPjtpWYil64qPQFKtADASwFD/GKmyhRtXZ+ClpyhNOdkXohyJ\nZf3zynjI6QZU5jG6gR0dtR50t3T79gWdivXQAdavc2HhZjKtp3TWS/2GssS3lJIx\n7I/2ymxE7Y5tVf5GbE0aqK5x2DGUFjvQD8tAf1XC+l/9QqXJs5+goK6ZIhwgQG5C\nB1+qESL3nj1LnM38mMxFjlAFNwsinjyDtb1tX03udESo+7L0pCa+cs4EIeIp6Oz+\nRwIDAQAB"
    $TUMBLER_RSA_PRIVATE_KEY="MIIEpAIBAAKCAQEAnGyt+yEPqJXudkpKrYT4A7s5NCprMnu58EUd/8qMZDX2XfqK\nN67fG0iHrI62gi5ApOE/sM6fY3pZUXQHLuDhSgqJ0uaOgzF9f2xDPjtpWYil64qP\nQFKtADASwFD/GKmyhRtXZ+ClpyhNOdkXohyJZf3zynjI6QZU5jG6gR0dtR50t3T7\n9gWdivXQAdavc2HhZjKtp3TWS/2GssS3lJIx7I/2ymxE7Y5tVf5GbE0aqK5x2DGU\nFjvQD8tAf1XC+l/9QqXJs5+goK6ZIhwgQG5CB1+qESL3nj1LnM38mMxFjlAFNwsi\nnjyDtb1tX03udESo+7L0pCa+cs4EIeIp6Oz+RwIDAQABAoIBADnLVcTRhE2Ph9mg\nvVK7LD+Ery/89DpkyGBjyR+3IIPuBCbY6LSGIdycwbQZzojuueexaazTysQgclvL\n+NNzNwn6Ns37bXA/mtS3lWiq3tO7z0HloePsKAtHt8Xipz3fhRv07ChvMgU+uLnE\n4hx9Wq6aU7bdRa4DLt8WRIhrz4wZLrObAJ3RshzpdhlcHHNdUddUwuulEcPCYSpT\nUdfJbzlmE0o3QSw14F4+6NSjNIYr5PTqzzmPZN0zem9yrreN3xHzFJW3z7oASx9m\n2WvvFET0S3TdfPqA0B5kQWSwSUE2X6NnCvW5q+JjPIE/X44JK9zpXY0hZs2DAETy\noTMjrFECgYEAzCARK5AcTrBzDg5+uXdbo7ziEZqKoS9CVjUmuOyJ9mGIGV+qPC+c\nswFk9cfjNDTmdZbb6LJyt1RSavtsxlC3lZCLoz0HZHYrJV6x+zOXcjLA2YEPvMis\nd1j9jqkDiMv1+lsqVxjKfiN5/ZvV+hXWUuM3SS18kMYwOD47KtaXf7MCgYEAxC1P\nQkvg+koDAuCmPau9cp9JL2IQp6p7/76XCU05EP2vaLHXSodxakZlsG7VF46cCNlT\nbTheZT/ADbVVtjStuhlO7AghTSsgYIDvidw40NhbZpgOz+0fjMhjWIHK1M5dq5qe\nOjTFdpbyGrFkHL2TK+6aeQySPkNm6CkPqVpi3R0CgYEAuoyb5IohtLCBldkda3Zv\no6adnKT2CPTd1Vdh+iMCus7LyRSqybJhrR6bHBv/wtiNve2PMIzVVkKTx/3bnSpr\nfR7K3vaJaQCt0ctHMWInCFDl+mF+9nMXW0NTByvjdQOh25mxikO326ukc2gWGCYY\n50uMXS5a5xyZOO12uWHAtw0CgYEAiEFsLoDjZxQm2UXNUUJKmCU4QLfdF4dbDruC\nzgwb2chJn+79uJ8wT/9LO+sPCIidqavAvTiMn8hSjXLocGBQVdSkM15GOwH8P+rt\n9RPHRo8vlKeCijqJUlAQaHXluj8HYlxHD+h9Siv3RkD1ZtzpLndQRUlM/f/0psV2\nQkssJaUCgYAoQIZi+LjOApr6oNnihePHyZhDuIsY57dYir7IKfqbiI82ZUv0laCT\ndrkUUA2G4gzch2SwYRG218B9GrIcf+bHJHVeGvmWnxYy7fNcjw0C9CXnLe6mAz7u\nwe3oNvCfh86VUM9+RcQucIH69lJgqVFdNFMPpaJ2XjGEVCysJZqY5g"
    
    
  end
end
