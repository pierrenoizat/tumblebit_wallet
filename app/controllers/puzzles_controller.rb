class PuzzlesController < ApplicationController

  include Crypto # module in /lib

  def index
    @puzzles = Puzzle.page(params[:page]).order(created_at: :asc) 
  end
  
  def show
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
    @puzzle.generate_epsilon_values # TODO: remove, this is for testing purposes only, testing puzzle model
  end
  
  def create_blinding_factors
    # Fig. 3, steps 1,2,3
    # Alice creates 300 values for Tumbler, mixing 15 real values with 285 fake values
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
    
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
      @puzzle.save # save indices of real values to @puzzle.real_indices
    end
    puts "Real indices: #{@puzzle.real_indices}"
    
    # Exponent (part of the public key)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    # The modulus (aka the public key, although this is also used in the private key computations as well)
    n = $TUMBLER_RSA_PUBLIC_KEY
    
    salt=Random.new.bytes(32).unpack('H*')[0] # 256-bit random integer
    puts "Salt: #{salt}"
    r=[]
    for i in 0..299  # create 300 blinding factors
      # 285 ro values created by Alice
      # 15 r values created by Bob. Alice knows only d = y*r^^pk
      if @puzzle.real_indices.include? i.to_s
        r[i]=Random.new.bytes(10).unpack('H*')[0] # "8f0722a18b63d49e8d9a", size = 20 hex char, 80 bits, 10 bytes
      else
        r[i]=(Random.new.bytes(10).unpack('H*')[0].to_i(16)*salt.to_i(16) % n).to_s(16) # salt is same size as epsilon, otherwise Tumbler can easily tell real values from fake values based on the size of s
      end
    end
    
    
    # dump the 285 values to a new csv file for Tumbler
    @ro_values = []
    require 'csv'
    string = OpenSSL::Digest::SHA256.new.digest(@puzzle.id.to_s).unpack('H*').first[0..5]
    
    if File.exists?("app/views/products/rovalues#{string}.csv")
      File.delete("app/views/products/rovalues#{string}.csv") # delete any previous version of file
    end
    
    CSV.open("app/views/products/rovalues#{string}.csv", "ab") do |csv|
      for i in 0..299
        unless @puzzle.real_indices.include? i.to_s
          @ro_values[i] = r[i]
        end
      end
      @ro_values.each do |ro|
        csv << [ro]
        end
      end # of CSV.open (writing to rovalues123456.csv)
    
    @beta_values = []
    # first, compute 15 real beta values

    p = @puzzle.y.to_i  # y = epsilon^^pk
    # The secret exponent (aka the private key)
    d = Figaro.env.tumbler_rsa_private_key.to_i(16)
    epsilon = mod_pow(p,d,n)
    puts "y: #{@puzzle.y.to_i.to_s(16)}"
    puts "Epsilon: #{epsilon.to_s(16)}"
    puts "Epsilon in db: #{@script.contract}"
    
    m = @script.contract.to_i(16)
    puzzle = mod_pow(m,e,n) # epsilon^pk mod n
    puts "puzzle: %x" % puzzle

    # puzzle solution
    d = Figaro.env.tumbler_rsa_private_key.to_i(16)
    solution = mod_pow(puzzle,d,n) # puzzle^sk mod modulus
    puts "Solution (epsilon):" + solution.to_s(16)
    puts "Script contract:" + @script.contract # solution should be equal to contract
    
    
    @puzzle.real_indices.each do |i|
      m = r[i.to_i].to_i(16)
      b = mod_pow(m,e,n)
      beta_value = (p*b) % n
      @beta_values[i.to_i] = beta_value.to_s(16)
    end
    
    # compute 285 fake values to complete beta_values
    k = 0
    for i in 0..299
      if @beta_values[i].blank?
        m = r[i].to_i(16)
        beta_value = mod_pow(m,e,n)
        @beta_values[i] = beta_value.to_s(16)
        k += 1
      end
    end
    puts "Number of fake values: #{k}"
    puts "Total number of values: #{@beta_values.count}"
    
    # Alice sends the 300 values to Tumbler in a CSV file
    # dump the 300 values to a new csv file for Tumbler
    if File.exists?("tmp/betavalues#{string}.csv")
      File.delete("tmp/betavalues#{string}.csv") # delete any previous version of file
    end
    
    CSV.open("tmp/betavalues#{string}.csv", "ab") do |csv|
      @beta_values.each do |beta|
        csv << [beta]
        end
      end # of CSV.open (writing to betavalues123456.csv)
    
  end
  
  
  def tumbler_encrypts_values
    # Fig. 3, step 4
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
    
    # Tumbler reads the 300 values from Alice's CSV file
    # then, Tumbler computes beta^^sk = s for each of the 300 beta values
    row_count = 0
    string = OpenSSL::Digest::SHA256.new.digest(@puzzle.id.to_s).unpack('H*').first[0..5]
    data = open("tmp/betavalues#{string}.csv").read
    @s_values = []

    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    # The secret exponent (aka the private key)
    d = Figaro.env.tumbler_rsa_private_key.to_i(16)
    require 'csv'
    CSV.parse(data) do |row|
      row.each do |beta|
        @s_values << mod_pow(beta.to_i(16),d,n).to_s(16) # encrypt beta_value with d, tumbler's RSA private key (sk)
      end
      row_count+=1
    end # do |row| (read input file)
    puts "Number of lines in file: " + row_count.to_s
    
    # dump s_values to a new csv file
    if File.exists?("app/views/products/svalues#{string}.csv")
      File.delete("app/views/products/svalues#{string}.csv") # delete any previous version of file
    end
    
    CSV.open("app/views/products/svalues#{string}.csv", "ab") do |csv|
      @s_values.each do |s|
        csv << [s]
        end
      end # of CSV.open (writing to svalues123456.csv)
      
    # Tumbler then picks 300 random symetric encryption key k (128 bits) and computes 
    # c = Enc(k, s) and h = H(k)
    @k_values = []
    @c_values = []
    @h_values = []
    for i in 0..299
      data = @s_values[i]
      cipher = OpenSSL::Cipher::AES.new(128, :CBC)
      cipher.encrypt # put cipher in encrypt mode
      key = cipher.random_key  # generate random AES encryption key
      key_hex = key.to_hex
      
      iv = cipher.random_iv # generate random AES initialization vector
      iv_hex = iv.to_hex
      
      k = key_hex + iv_hex  # random symetric encryption key

      key_hex = k.to_s[0..31]
      iv_hex = k.to_s[32..63]
      key = key_hex.from_hex
      iv = iv_hex.from_hex
      
      cipher.key = key
      cipher.iv = iv
      encrypted = cipher.update(data) + cipher.final

      decipher = OpenSSL::Cipher::AES.new(128, :CBC)
      decipher.decrypt
      
      decipher.key = key
      decipher.iv = iv

      plain = decipher.update(encrypted) + decipher.final
      if data == plain
        @k_values[i] = k
        @c_values[i] = BTC::Data.hex_from_data(encrypted)
        @h_values[i] = k.ripemd160.to_hex
      else
        redirect_to @puzzle, alert: "Problem with signature encryption."
      end
    end
    
    # dump the 300 (c, h) couples to a new csv file for Alice
    if File.exists?("app/views/products/chvalues#{string}.csv")
      File.delete("app/views/products/chvalues#{string}.csv") # delete any previous version of file
    end
    
    CSV.open("app/views/products/chvalues#{string}.csv", "ab") do |csv|
      for i in 0..299
        csv << [@c_values[i],@h_values[i]]
        end
      end # of CSV.open (writing to chvalues123456.csv)
      
    # dump the 300 k values to a new csv file for Tumbler to keep
    if File.exists?("app/views/products/kvalues#{string}.csv")
      File.delete("app/views/products/kvalues#{string}.csv") # delete any previous version of file
    end

    CSV.open("app/views/products/kvalues#{string}.csv", "ab") do |csv|
      for i in 0..299
        csv << [@k_values[i]]
        end
      end # of CSV.open (writing to kvalues123456.csv)
    
  end
  
  
  def tumbler_checks_ro_values
    # Fig. 3, step 6
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
    string = OpenSSL::Digest::SHA256.new.digest(@puzzle.id.to_s).unpack('H*').first[0..5]
    data = open("app/views/products/rovalues#{string}.csv").read
    @ro_values = []

    # Tumbler reads file with 285 "fake" ro values
    require 'csv'
    CSV.parse(data) do |row|
      row.each do |ro|
          @ro_values << ro
      end
    end # do |row| (read input file)
    
    # Tumbler verifies beta = ro^^pk for all ro values
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    
    # Tumbler reads the 300 beta values from Alice's CSV file
    # then, Tumbler computes ro^^pk for each of the 285 ro values
    # finally, Tumbler verifies beta = ro^^pk for all ro values
    row_count = 0
    data = open("tmp/betavalues#{string}.csv").read
    @beta_values = []
    CSV.parse(data) do |row|
      row.each do |beta|
        @beta_values << beta.to_i(16)
      end
      row_count+=1
    end # do |row| (read input file)
    puts "Number of beta values in file: " + row_count.to_s
    
    true_count = 0
    for i in 0..299
      unless @puzzle.real_indices.include? i.to_s
        ro = @ro_values.shift.to_i(16)
        if (@beta_values[i] == mod_pow(ro,e,n))
          true_count+=1
        end
      end
    end
    puts "Number of ro values checked: " + true_count.to_s
    
    unless true_count == 285
      redirect_to @puzzle, alert: "Invalid ro values."
    else
      # Tumbler reads k values from his csv file
      data = open("app/views/products/kvalues#{string}.csv").read
      @k_values = []
      CSV.parse(data) do |row|
        row.each do |k|
          @k_values << k
        end
      end # do |row| (read input file)
      
      # dump the 285 "fake" k values to a new csv file for Tumbler to send to Alice
      if File.exists?("app/views/products/fkvalues#{string}.csv")
        File.delete("app/views/products/fkvalues#{string}.csv") # delete any previous version of file
      end

      CSV.open("app/views/products/fkvalues#{string}.csv", "ab") do |csv|
        for i in 0..299
          unless @puzzle.real_indices.include? i.to_s
            csv << [@k_values[i]]
          end
        end
      end
      # Tumbler sends csv file with 285 k values (encryption keys) to Alice: TODO download button in view
    end
    
  end
  
  
  def sender_checks_k_values
    # Fig 3, step 7
    # Alice verifies now that h = H(k), computes s = Dec(k,c) and verifies also that s^^pk = beta
    
    @puzzle = Puzzle.find(params[:id])
    @script =Script.find(@puzzle.script_id)
    
    # Alice reads the 285 "fake" (c,h) values from Tumbler's CSV file
    row_count = 0
    string = OpenSSL::Digest::SHA256.new.digest(@puzzle.id.to_s).unpack('H*').first[0..5]
    data = open("app/views/products/chvalues#{string}.csv").read
    @c_values = []
    @h_values = []
    require 'csv'
    i = 0
    j = 0
    CSV.parse(data) do |row|
      ch_array = []
      row.each do |c|
        ch_array << c
      end
      unless @puzzle.real_indices.include? i.to_s
        @c_values[j] = row[0]
        @h_values[j] = row[1]
        j += 1
      end
      i += 1
      row_count+=1
    end # do |row| (read input file)
    puts "Number of (c,h) lines in file: " + row_count.to_s
    puts "Number of fake c values: " + @c_values.count.to_s
    
    # Alice reads the 285 k values from Tumbler's CSV file and verifies that h = H(k)
    row_count = 0
    true_count = 0
    data = open("app/views/products/fkvalues#{string}.csv").read
    @fk_values = []
    require 'csv'
    i = 0
    CSV.parse(data) do |row|
      row.each do |k|
        @fk_values[i] = k
        h = @h_values.shift
        if h == k.ripemd160.to_hex
          true_count += 1
        else
          puts "h: " + h
          puts "k: " + k
        end
      end
      i += 1
      row_count+=1
    end # do |row| (read input file)
    puts "Number of k values checked successfully: " + true_count.to_s
    
    unless true_count == 285
      redirect_to @puzzle, alert: "Mismatch between h and H(k) values."
    else
      # Alice now computes s = Dec(k,c) and verifies that s^^pk = beta
      e = $TUMBLER_RSA_PUBLIC_EXPONENT
      n = $TUMBLER_RSA_PUBLIC_KEY

      true_count = 0
      @s_values = []

      for i in 0..284
        k = @fk_values[i]
        c = @c_values[i]
        decipher = OpenSSL::Cipher::AES.new(128, :CBC)
        decipher.decrypt
        key_hex = k[0..31]
        iv_hex = k[32..63]
        key = key_hex.from_hex
        iv = iv_hex.from_hex
        decipher.key = key
        decipher.iv = iv
        @s_values[i] =  decipher.update(BTC::Data.data_from_hex(c)) + decipher.final
      end
      
      i = 0
      data = open("tmp/betavalues#{string}.csv").read
      @beta_values = []
      CSV.parse(data) do |row|
        row.each do |beta|
          unless @puzzle.real_indices.include? i.to_s
            @beta_values << beta.to_i(16)
          end
        end
        i +=1
      end # do |row| (read input file)
      puts "Number of beta values in file: " + i.to_s
      
      true_count = 0
      for i in 0..284
        if (@beta_values[i] == mod_pow(@s_values[i].to_i(16),e,n))  # verify s^^pk = beta (real values)
          true_count += 1
        end
      end
      puts "Number of s values checked successfully: " + true_count.to_s
      unless true_count == 285
        redirect_to @puzzle, alert: "Mismatch between s and beta values."
      end
      
    end
    
  end


  private
 
     def puzzle_params
       params.require(:puzzle).permit(:script_id, :y, :encrypted_signature)
     end

end