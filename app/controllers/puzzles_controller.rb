class PuzzlesController < ApplicationController

  def index
    @puzzles = Puzzle.page(params[:page]).order(created_at: :asc) 
  end
  
  def show
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
  end
  
  def create_blinding_factors
    # Alice creates 300 values for Tumbler, mixing 15 real values with 285 fake values
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
    
    r=[]
    for i in 0..299  # create 300 blinding factors
      r[i]=Random.new.bytes(10).unpack('H*')[0] # "8f0722a18b63d49e8d9a", size = 20 hex char, 80 bits, 10 bytes
    end
    
    if @puzzle.real_indices.blank?
      real_indices = []
      prng = Random.new
      while real_indices.count < 15
        j = prng.rand(0..299)
        unless real_indices.include? j
          real_indices << j
        end
      end
      @puzzle.real_indices = real_indices
      @puzzle.save # save indices of real values for @puzzle
    end
    puts "Saved: #{@puzzle.real_indices}"
    
    beta_values = []
    # compute 15 real values
   
    # Exponent (part of the public key)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    # The modulus (aka the public key, although this is also used in the private key as well)
    n = $TUMBLER_RSA_PUBLIC_KEY
    # The secret exponent (aka the private key)
    d = Figaro.env.tumbler_rsa_private_key.to_i(16)
    
    @puzzle.real_indices.each do |i|
      m = r[i.to_i].to_i(16)
      blinding_factor = mod_pow(m,e,n)
      b = blinding_factor%n # TODO check that modulus is not required
      p = @puzzle.y.to_i(16)%n
    
      @real_value = (p*b)%n
      beta_values[i.to_i] = @real_value.to_s(16)
    end
    
    # compute 285 fake values
    for i in 0..299
      if beta_values[i].blank?
        m = r[i].to_i(16)
        blinding_factor = mod_pow(m,e,n)
        b = blinding_factor%n # TODO check that modulus is not required
    
        @fake_value = b
        beta_values[i] = @fake_value.to_s(16)
      end
    end
    puts "Number of values: #{beta_values.count}"
    
    # send the 300 values to Tumbler in a CSV file
    @puzzle.beta_values = beta_values
    @puzzle.save
    dump_to_csv(@puzzle.id)
    
  end
  
  def tumbler_encrypts_values
    r = params[:r]
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
    
    # TODO: Tumbler reads the 300 values from Alice's CSV file
    
    real_value = r.to_i(16)
    puts "Original: %x" % real_value

    # Exponent (part of the public key)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    # The modulus (aka the public key, although this is also used in the private key as well)
    n = $TUMBLER_RSA_PUBLIC_KEY
    # The secret exponent (aka the private key)
    d = Figaro.env.tumbler_rsa_private_key.to_i(16)
    
    # RSA exponentiation
    @real_s = mod_pow(real_value,d,n) # encrypt real_value with d, tumbler's RSA private key (sk)
    puts "Encrypted: %x" % @real_s
    
    # Decrypt
    a = mod_pow(@real_s,e,n)
    puts "Decrypted: %x" % a
    
  end
  
  def mod_pow(base, power, mod)
    result = 1
    while power > 0
      result = (result * base) % mod if power & 1 == 1
      base = (base * base) % mod
      power >>= 1;
    end
    result
  end
  
  # Convert a string into a big number
  def str_to_bignum(s)
    n = 0
    s.each_byte{|b|n=n*256+b}
    n
  end
  
  # Convert a bignum to a string
  def bignum_to_str(n)
    s=""
    while n>0
      s = (n&0xff).chr + s
      n >>= 8
    end
    s
  end


  private
 
     def puzzle_params
       params.require(:puzzle).permit(:script_id, :y, :encrypted_signature)
     end

end