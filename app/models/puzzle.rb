class Puzzle < ActiveRecord::Base
    belongs_to :script
    require 'btcruby/extensions'
    include Crypto # module in /lib
    
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
      puts "Epsilon: #{epsilon[0]}"
      z = generate_z(epsilon[0])
      generate_blinded_puzzle(z)
    end
    
    def generate_bitcoin_key_pair
      require 'btcruby/extensions'
      keychain = BTC::Keychain.new(xprv:Figaro.env.tumbler_btc_msk)
      key = keychain.derived_keychain("#{self.id}/4").key
      puts key.address # compressed address
      puts key.to_wif # compressed wif
    end
    
    def generate_z(epsilon)
      # returns puzzle z = (epsilon)**pk where pk is Tumbler RSA public key
      # Exponent (part of the public key)
      e = $TUMBLER_RSA_PUBLIC_EXPONENT
      # The modulus (aka the public key, although this is also used in the private key computations as well)
      n = $TUMBLER_RSA_PUBLIC_KEY
      z = mod_pow(epsilon.to_i(16),e,n) # epsilon^pk mod n
      puts "z: #{z.to_s(16)}"
      z
    end
    
    def generate_blinded_puzzle(z)
      e = $TUMBLER_RSA_PUBLIC_EXPONENT
      n = $TUMBLER_RSA_PUBLIC_KEY.to_i
      r = Random.new.bytes(16).unpack('H*')[0].to_i(16) # 128-bit random integer, Bob keeps it secret
      big_r = mod_pow(r,e,n) # r^pk mod n
      puts "R: #{r.to_s(16)}"
      blinded_puzzle = big_r*z % n
      puts "Blinded puzzle: #{blinded_puzzle.to_s(16)}" 
    end
    
end
