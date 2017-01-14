class Puzzle < ActiveRecord::Base
    belongs_to :script
    require 'btcruby/extensions'
    def generate_epsilon_values
      # Tumbler picks 300 128-bit epsilon values with epsilon < n, RSA public key modulus of Tumbler.
      epsilon = []
      n = $TUMBLER_RSA_PUBLIC_KEY.to_i
      k = 0
      300.times do
        value = n
        while (value >= n)
          value = Random.new.bytes(16).unpack('H*')[0].to_i(16) # 128-bit random integer
          k += 1
        end
        epsilon << value.to_s(16)
      end
      epsilon # returns array of 300 values (hex strings)
    end
    
    def generate_bitcoin_key_pair
      require 'btcruby/extensions'
      keychain = BTC::Keychain.new(xprv:Figaro.env.tumbler_btc_msk)
      key = keychain.derived_keychain("#{self.id}/4").key
      puts self.id
      puts key.address # compressed address
      puts key.to_wif # compressed wif
    end
    
end
