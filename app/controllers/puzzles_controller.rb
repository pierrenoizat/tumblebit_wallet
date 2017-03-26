class PuzzlesController < ApplicationController

  include Crypto # module in /lib
  require 'csv'
  require 'btcruby/extensions'
  
  
  def index
    if params[:search]
      @puzzles = Puzzle.search(params[:search]).order("created_at DESC")
      @puzzle = @puzzles.first
      if (@puzzles.count == 1 or @puzzles.count == 2)
        if @puzzle.alice_public_key
          @beta_filename = "beta_values_" + @puzzle.funded_address.to_s + ".csv"
          render :show_alice_step_3
        else
          render :show_alice_step_2
        end
      else
        puts "Count = #{@puzzles.count}" 
        @puzzles = Puzzle.page(params[:page]).order(created_at: :desc)
        redirect_to puzzles_url, alert: 'No puzzle found with this y value.'
      end
    else
      @puzzles = Puzzle.page(params[:page]).order(created_at: :desc)
    end
  end
  
  
  def new
    @puzzle = Puzzle.new
  end
  
  
  def show
    @puzzle = Puzzle.find(params[:id])

    @funding_script = @puzzle.funding_script
    @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(@puzzle.tumbler_public_key))
    
    @funded_address = @puzzle.funded_address
   end
  
  def create
    @puzzle = Puzzle.new(puzzle_params)

    real_indices = []
    if @puzzle.real_indices.blank?
      prng = Random.new
      while real_indices.count < 15
        j = prng.rand(0..299)
        unless real_indices.include? j
          real_indices << j
        end
      end
      @puzzle.real_indices = real_indices
    end
    real_indices = @puzzle.real_indices
    puts "Real indices: #{real_indices}"
    
    fake_indices = []
    if @puzzle.fake_indices.blank?
      prng = Random.new
      while fake_indices.count < 42
        j = prng.rand(0..83)
        unless fake_indices.include? j
          fake_indices << j
        end
      end
      @puzzle.fake_indices = fake_indices
    end
    fake_indices = @puzzle.fake_indices
    puts "Fake indices: #{fake_indices}"
    
    @previous_id = @puzzle.escrow_txid
    
    if @previous_id
      string = "https://api.blockcypher.com/v1/btc/main/txs/" + @previous_id 
      @agent = Mechanize.new

      begin
        page = @agent.get string
      rescue Exception => e
        page = e.page
      end

      data = page.body
      result = JSON.parse(data)
      @puzzle.escrow_amount = result["total"].to_i
      puts "Value of escrow tx in satoshis = #{@puzzle.escrow_amount}"
    end
    
    @puzzle.save
    render "show", notice: 'Puzzle was successfully created.'
  end
  
  
  def update
    @puzzle = Puzzle.find(params[:id])
    if params[:puzzle][:solution]
      # @solution = params[:puzzle][:solution]
      bob_gets_sigma(params[:puzzle][:solution])
      render :bob_gets_sigma
    else
      @puzzle.update_attributes(puzzle_params)
      if @puzzle.alice_public_key
        string = @puzzle.funded_address.to_s
        puts string
        unless File.exists?("app/views/products/beta_values_#{string}.csv")
          alice_step_3
        end
        @beta_filename = "beta_values_" + @puzzle.funded_address.to_s + ".csv"
        render :show_alice_step_3
      else
        render :show_alice_step_2
      end
    end
  end
  
  
  def alice_step_3
    # Fig. 3, steps 1,2,3
    # Alice creates 300 values for Tumbler, mixing 15 real values with 285 fake values
    @puzzle = Puzzle.find(params[:id])
    string = @puzzle.funded_address.to_s
    @beta_filename = "beta_values_" + string + ".csv"
    
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
    
    real = []
    @puzzle.real_indices.each do |ri|
      real << ri.strip # avoid problems with extra leading or trailing space caracters
    end
    
    # Exponent (part of the public key)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    # The modulus (aka the public key, although this is also used in the private key computations as well)
    n = $TUMBLER_RSA_PUBLIC_KEY
    
    salt=Random.new.bytes(32).unpack('H*')[0] # 256-bit random integer
    puts "Salt: #{salt}"
    r=[]
    for i in 0..299  # create 300 blinding factors
      # 285 fake ro values, 15 real r values
      if real.include? i.to_s
        r[i]=Random.new.bytes(10).unpack('H*')[0] # "8f0722a18b63d49e8d9a", size = 20 hex char, 80 bits, 10 bytes
      else
        r[i]=(Random.new.bytes(10).unpack('H*')[0].to_i(16)*salt.to_i(16) % n).to_s(16) # salt is same size as epsilon, otherwise Tumbler can easily tell real values from fake values based on the size of s
      end
    end
    
    
    # dump the 285 fake values to a new csv file for Tumbler
    @ro_values = []
    for i in 0..299
      unless real.include? i.to_s
        @ro_values[i] = r[i]
      else
        @ro_values[i] = nil
      end
    end
    require 'csv'
    
    if File.exists?("app/views/products/ro_values_#{string}.csv")
      File.delete("app/views/products/ro_values_#{string}.csv") # delete any previous version of file
    end
    
    CSV.open("app/views/products/ro_values_#{string}.csv", "ab") do |csv|
      @ro_values.each do |ro|
        csv << [ro]
        end
      end # of CSV.open (writing to ro_values_123456.csv)
    
      # dump the 15 real r values to a new csv file to keep: Alice reveals it after step 7
      @r_values = []
      for i in 0..299
        if real.include? i.to_s
          @r_values[i] = r[i]
        else
          @r_values[i] = nil
        end
      end
      require 'csv'

      if File.exists?("app/views/products/r_values_#{string}.csv")
        File.delete("app/views/products/r_values_#{string}.csv") # delete any previous version of file
      end

      CSV.open("app/views/products/r_values_#{string}.csv", "ab") do |csv|
        @r_values.each do |rr|
          csv << [rr]
          end
        end # of CSV.open (writing to r_values_123456.csv)
    
    @beta_values = []
    # first, compute 15 real beta values

    p = @puzzle.y.to_i(16)  # y = epsilon^^pk

    puts "y: #{@puzzle.y}"
    
    real.each do |i|
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
    if File.exists?("app/views/products/beta_values_#{string}.csv")
      File.delete("app/views/products/beta_values_#{string}.csv") # delete any previous version of file
    end
    
    CSV.open("app/views/products/beta_values_#{string}.csv", "ab") do |csv|
      @beta_values.each do |beta|
        csv << [beta]
        end
      end # of CSV.open (writing to "app/views/products/beta_values_#{string}.csv")
    
  end
  
  def bob_step_2
    # Steps 2 and 3 in Tumbler-Bob interactions, performed by Bob
    # Bob generates 42 “real” payout addresses (keeps them secret for now) and prepares 42 distinct “real” transactions.
    @puzzle = Puzzle.find(params[:id])
    real_indices = @puzzle.real_indices
    puts "Real indices: #{real_indices}"

    beta = []
    real_indices.each do |i|
      beta[i.to_i] = @puzzle.real_btc_tx_sighash(i.to_i)
    end
    
    # In Step 3, Bob picks a random secret 256-bit blinding factor r and prepares 42 “fake” transactions.
    
    # Fake transaction i pays Tumbler compressed Bitcoin address 1 BTC in output 0 
    # with an OP_RETURN output (output 1) bearing r || i. 
    # No network fee is implied in the fake transaction.

    for i in 0..83
      unless @puzzle.real_indices.include? i.to_s
        beta[i] = @puzzle.fake_btc_tx_sighash(i)
      end
    end
    puts beta.count
    @puzzle.beta_values = beta
    @puzzle.save
    puts beta
    # dump 84 beta values to csv file for Tumbler
    if File.exists?("app/views/products/beta_values_#{@puzzle.funded_address}.csv")
      File.delete("app/views/products/beta_values_#{@puzzle.funded_address}.csv") # delete any previous version of file
    end
    
    CSV.open("app/views/products/beta_values_#{@puzzle.funded_address}.csv", "ab") do |csv|
      beta.each do |b|
        csv << [b]
        end
      end # of CSV.open (writing to beta_values_#{@puzzle.funded_address}.csv)
    
    redirect_to @puzzle, notice: 'Transactions were successfully created by Bob.'
    
  end # of bob_step_2
  
  
  def bob_step_8
    # For all fake epsilon values provided by Tumbler, Bob checks that sigmai = Dec(epsiloni, ci) 
    # and ECDSA-verifies the signature against PKT and betai = sighashi.
    # Bob aborts the protocol if any check fails.
    @puzzle = Puzzle.find(params[:id])
    r = @puzzle.r
    data = open("app/views/products/fake_epsilon_values_#{@puzzle.funded_address}.csv").read
    @fake_epsilon_values = []
    j = 0
    CSV.parse(data) do |row|
      fake_epsilon_array = []
      row.each do |f|
        fake_epsilon_array << f
        @fake_epsilon_values[j] = fake_epsilon_array[0]
      end
      j+=1
    end # do |row| (read input file)
    puts "Number of fake epsilon values in file: " + j.to_s
    
    data = open("app/views/products/c_z_values_#{@puzzle.funded_address}.csv").read
    @c_values = []
    @z_values = []
    j = 0
    CSV.parse(data) do |row|
      c_z_array = []
      row.each do |f|
        c_z_array << f
        @c_values[j] = c_z_array[0]
        @z_values[j] = c_z_array[1]
      end
      j+=1
    end # do |row| (read input file)
    puts "Number of c values in file: " + j.to_s
    # Bob computes sigmai = Dec(epsiloni, ci) for the 42 fake epsilon values
    @sigma = []
    @beta = []
    j = 0
    @r = @puzzle.r.to_i

    @tumbler_key=BTC::Key.new(public_key:BTC.from_hex(@puzzle.tumbler_public_key))
    puts @tumbler_key.address
    @result = false
    
    for i in 0..83
      unless @puzzle.real_indices.include? i.to_s
        k = @fake_epsilon_values[j]
        while k.size < 64
          k = "0" + k # padding with leading zeroes in case of low epsilon value
        end
        puts "fake epsilon: #{k}"
        key_hex = k[0..31]
        iv_hex = k[32..63]
        key = key_hex.from_hex
        iv = iv_hex.from_hex
        decipher = OpenSSL::Cipher::AES.new(128, :CBC)
        decipher.decrypt
        decipher.key = key
        decipher.iv = iv
        @sigma[j] = decipher.update(@c_values[i].from_hex) + decipher.final
        puts "fake sigma value = #{@sigma[j].unpack('H*')[0]}"
        puts "c value = #{@c_values[i]}"
        
        # Bob checks that sigmai is a valid ECDSA signature against PKT and betai
        @beta[j] = @puzzle.fake_btc_tx_sighash(i)
        puts "beta = #{@beta[j]}"
        @result = @tumbler_key.verify_ecdsa_signature(@sigma[j], @beta[j].htb)  # result must equal true
        if @result
          j += 1
        else
          puts j
          redirect_to @puzzle, alert: 'There is a problem with Tumblers fake epsilons: Bob should abort protocol.'
          return
        end
      end
    end
    if j == 42
      redirect_to @puzzle, notice: 'Tumblers fake epsilons were successfully checked by Bob.'
    end
  
  end # of bob_step_8
  
  
  def bob_step_10
    # In step 10, Bob computes zj1*(q2)pk = (epsilonj2)pk and checks that zj2 = zj1*(q2)pk
    # If any check fails, Bob aborts the protocol.
    # If no fail, Tumbler is very likely to have sent validly formed zi values.
    @puzzle = Puzzle.find(params[:id])
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    data = open("app/views/products/quotient_values_#{@puzzle.funded_address}.csv").read
    @quotient = []
    @num = []
    @denum = []
    j = 0
    CSV.parse(data) do |row|
      quotient_array = []
      row.each do |f|
        quotient_array << f
        @quotient[j] = quotient_array[0].to_i
      end
      j+=1
    end # do |row| (read input file)
    puts "Number of quotient values in file: " + j.to_s
    
    data = open("app/views/products/c_z_values_#{@puzzle.funded_address}.csv").read
    @z_values = []
    j = 0

    CSV.parse(data) do |row|
      c_z_array = []
      row.each do |zeta|
        c_z_array << zeta
      end
      # @z_values[j] = c_z_array[1].to_i(16)
      @z_values[j] = c_z_array[1]
      j+=1
    end # do |row| (read input file)
    puts "Number of z values in file: " + j.to_s
    
    j = 0
    real = []
    @puzzle.real_indices.each do |ri|
      real << ri.strip # avoid problems with extra leading or trailing space caracters
    end
    @real_z_values = []
    for i in 0..83
      if real.include? i.to_s
        @real_z_values << @z_values[i]
      end
    end
    puts "Number of real z values : " + @real_z_values.count.to_s

    puts "check that z2 = z1*(q2)^pk mod n"
    # check that z2 = z1*(q2)^pk mod n :

    j = 0
    for i in 0..40
      z2 = @real_z_values[i+1].to_i(16)
      z1 = @real_z_values[i].to_i(16)
      q2 = @quotient[i]
      puts z2.to_s(16)
      puts z1.to_s(16)
      puts q2
      if (z2 == (z1*mod_pow(q2, e, n) % n))
        j += 1
      else
        puts "Failed test, should be zero:" + ((z2 - z1*mod_pow(q2, e, n)) % n).to_s
      end
      puts j
    end
    
    if j == 41
      # TODO: Bob step 12
      # Bob picks random R and keeps it secret
      # Bob sets z= zj1 = (epsilonj1)**e = @real_z_values[0] and sends y = z*(R**e)  to Alice
       @puzzle.y = @real_z_values[0].to_i(16)*mod_pow(@puzzle.r.to_i, e, n) % n
       @puzzle.save
      redirect_to @puzzle, notice: 'Tumblers RSA quotients were successfully checked by Bob.'
    else
      puts j
      redirect_to @puzzle, alert: 'There is a problem with Tumblers RSA quotients: Bob should abort protocol.'
    end
    
  end # of bob_step_10
  
  
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
  
  
  def alice_step_7
    # Fig 3, step 7
    # Alice verifies now that h = H(k), computes s = Dec(k,c) and verifies also that s^^pk = beta
    
    @puzzle = Puzzle.find(params[:id])
    # @script =Script.find(@puzzle.script_id)
    
    # Alice reads the 285 "fake" (c,h) values from Tumbler's CSV file
    row_count = 0
    # string = OpenSSL::Digest::SHA256.new.digest(@puzzle.id.to_s).unpack('H*').first[0..5]
    string = @puzzle.funded_address
    data = open("app/views/products/c_h_values_#{string}.csv").read
    @c_values = []
    @h_values = []
    @real_c_values = []
    @real_h_values = []
    @real_k_values = []
    @real_beta_values = []
    i = 0
    j = 0
    m = 0
    @contract = ""
    real = []
    @puzzle.real_indices.each do |ri|
      real << ri.strip # avoid problems with extra leading or trailing space caracters
    end
    
    CSV.parse(data) do |row|
      ch_array = []
      row.each do |c|
        ch_array << c
      end
      if real.include? i.to_s
        @real_c_values[m] = row[0]
        @real_h_values[m] = row[1]
        @contract += @real_h_values[m]
        m += 1
      else
        @c_values[j] = row[0]
        @h_values[j] = row[1]
        j += 1
      end
      i += 1
      row_count+=1
    end # do |row| (read input file)
    puts "Number of (c,h) lines in file: " + row_count.to_s
    puts "Number of fake c values: " + @c_values.count.to_s
    puts "Number of real h values: " + @real_h_values.count.to_s
    puts "Contract: " + @contract
    
    # Alice reads the 285 k values from Tumbler's CSV file and verifies that h = H(k)
    row_count = 0
    true_count = 0
    data = open("app/views/products/fake_k_values_#{string}.csv").read
    @fk_values = []

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
      data = open("app/views/products/beta_values_#{string}.csv").read
      @beta_values = []
      CSV.parse(data) do |row|
        row.each do |beta|
          if real.include? i.to_s
            @real_beta_values << beta.to_i(16)
          else
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
      if true_count == 285
        # Alice posts Tpuzzle offering 1 bitcoin within timewindow tw1
        # under condition: the fulfilling transaction is signed by T and has preimages of (real) h_values
        # then Alice sends y and real r values to Tumbler
        if @puzzle.script_id
          @script = @puzzle.script
          @alice_pub_key = PublicKey.where({ name: "Alice", script_id: @script.id }).last
          @tumbler_pub_key = PublicKey.where({ name: "Tumbler", script_id: @script.id }).last
        else
          @script = Script.create(title: "puzzle_#{string}",
                              tumbler_key: @puzzle.tumbler_public_key,
                              expiry_date: @puzzle.expiry_date,
                              contract: @contract,
                              category: "tumblebit_puzzle")

          @alice_pub_key = PublicKey.create(name: "Alice",
                              script_id: @script.id,
                              compressed: @puzzle.alice_public_key)
          @tumbler_pub_key = PublicKey.create(name: "Tumbler",
                              script_id: @script.id,
                              compressed: @puzzle.tumbler_public_key)
          @puzzle.script_id = @script.id
          @puzzle.save
        end
        
        if @puzzle.escrow_txid.blank?
          unless @script.virgin? or @script.funded?
            url_string = $BLOCKR_ADDRESS_TXS_URL + @script.hash_address.to_s
            @agent = Mechanize.new
            puts "#{@script.hash_address}"
            begin
              page = @agent.get url_string
            rescue Exception => e
              page = e.page
            end

            data = page.body
            result = JSON.parse(data)
            puts "Number of transactions= #{result['data']['nb_txs']}"
            tx_hash = result['data']['txs'].first # in blockr API, first is most recent tx
            @puzzle.escrow_txid = tx_hash['tx']
            @puzzle.save
            puts "#{tx_hash['tx']}"
          end
        end
        
        unless @puzzle.escrow_txid.blank? # Learn kj from Tsolve
          url_string = $BLOCKR_RAW_TX_URL + @puzzle.escrow_txid
          @agent = Mechanize.new
          begin
            page = @agent.get url_string
          rescue Exception => e
            page = e.page
          end
          data = page.body
          result = JSON.parse(data)
          @transaction = BTC::Transaction.new(hex: result['data']['tx']['hex'])
          # puts "#{result['data']['tx']['hex']}" # raw_tx in hex
          # puts @transaction.dictionary['in'][0]['scriptSig']['asm']
          @words = @transaction.dictionary['in'][0]['scriptSig']['asm'].split(/\W+/) # array of real k values revealed by Tumbler
          for i in 1..15
      			@real_k_values[i-1] = @words[16-i].from_hex
      		end
          # Decrypt cj to sj = Hprg(kj) ⊕ cj
          i = 0
          data = open("app/views/products/r_values_#{string}.csv").read
          @r_values = []
          CSV.parse(data) do |row|
            row.each do |r|
              if real.include? i.to_s
                @r_values << r.to_i(16)
              end
            end
            i +=1
          end # do |row| (read input file)
          puts "Number of r values in file: " + i.to_s
          alice_step_11
        end
                            
      else
        redirect_to @puzzle, alert: "Mismatch between s and beta values."
      end
      
    end
    
  end # of alice_step_7
  
  
  def alice_step_11
    # Learned kj from Tsolve in alice_step_7
    # Decrypt 15 real cj to sj = Hprg(kj) ⊕ cj 
    @real_s_values = []
    # Tumbler picked 15 real random symetric encryption key k (128 bits) and computed 
    # c = Enc(k, s) and h = H(k)
    true_count = 0
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    for i in 0..14
      decipher = OpenSSL::Cipher::AES.new(128, :CBC)
      decipher.decrypt
      
      key_hex = @real_k_values[i].to_s[0..31]
      iv_hex = @real_k_values[i].to_s[32..63]
      key = key_hex.from_hex
      iv = iv_hex.from_hex
      decipher.key = key
      decipher.iv = iv
      encrypted = @real_c_values[i].from_hex
      @real_s_values[i] = decipher.update(encrypted) + decipher.final # plain
      if (@real_beta_values[i] == mod_pow(@real_s_values[i].to_i(16),e,n))  # verify s**e = beta mod n
        true_count += 1
      end
    end
    
    # Obtain solution sj/rj mod n
    @solution = ((@real_s_values[0].to_i(16)/@r_values[0]) % n).to_s(16)
    puts "Real s values"
    puts @real_s_values
    puts @solution
    puts true_count
    
    # Obtain solution sj/rj mod N 
    # which is y**d mod N.
    render "alice_step_7"
    
  end # of alice_step_11
  
  
  def bob_gets_sigma(solution)
    # get first real index value c from c_z_values_ file
    i = 0
    j = 0
    fake = []
    @puzzle.fake_indices.each do |ri|
      fake << ri.strip # avoid problems with extra leading or trailing space caracters
    end
    while fake.sort.include? i.to_s
      i += 1
    end
    
    data = open("app/views/products/c_z_values_33J92v6eddniyzq49CVMGmufp5AHxkb8Gj.csv").read
    @c_values = []
    
    CSV.parse(data) do |row|
      cz_array = []
      row.each do |c|
        cz_array << c
      end
      @c_values[j] = row[0]
      j += 1
    end # do |row| (read input file)
    c = @c_values[i]

    r = 39148868723064938442606470813898721572068782984532666654439715815924433438097
    epsilon = (solution.to_i(16)/r).to_s(16)
    decipher = OpenSSL::Cipher::AES.new(128, :CBC)
    decipher.decrypt

    key_hex = epsilon.to_s[0..31]
    iv_hex = epsilon.to_s[32..63]
    key = key_hex.htb
    iv = iv_hex.htb
    decipher.key = key
    decipher.iv = iv
    encrypted = c.htb
    sigma = decipher.update(encrypted) + decipher.final
    @sigma = sigma.unpack("H*").first
    # @sigma = "3044022019fcaa67c30105dd2427dbcd2d4e0132f452b4240dd46703b255c3bd7360b38e0220487a34da5c1af41610899bf06eed371e363c89de6e2c2da600575cd3a02955ce"
    
    string = $BLOCKR_ADDRESS_UNSPENT_URL + @puzzle.funded_address.to_s + "?unconfirmed=1" # P2SH address funded by Tumbler with_unconfirmed utxo
    @agent = Mechanize.new
    begin
    page = @agent.get string
    rescue Exception => e
    page = e.page
    end
    data = page.body
    result = JSON.parse(data)
    puts result
    if result['data']['unspent'].blank?
      puts "No utxo avalaible for #{@puzzle.funded_address}"
    end
    @tumbler_private_key = BTC::WIF.new(string:"L2dSPKfm998jApkYyF1CoM5zR6rYAassuSbgagMkyB8vxfpiEzFU")
    @tumbler_key=BTC::Key.new(wif:@tumbler_private_key.to_s)
    @bob_private_key = BTC::WIF.new(string:"L4wSWiYW3bEkvGQ5RvkYkPmdEah58mrBLSgNFEPqKjaVKKCJ4cxG")
    @bob_key=BTC::Key.new(wif:@tumbler_private_key.to_s)
    keychain = BTC::Keychain.new(xprv:Figaro.env.tumbler_btc_msk)
    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + @puzzle.id.to_i) % 0x80000000
    key = keychain.derived_keychain("8/#{index}").key
    @previous_id = result['data']['unspent'][0]['tx']
    @previous_index = 0
    @value = (result['data']['unspent'][0]['amount'].to_f)* BTC::COIN - $NETWORK_FEE

    tx = BTC::Transaction.new
    tx.lock_time = 1471199999 # some time in the past (2016-08-14), if before expiry
    # tx.lock_time = @puzzle.expiry_date.to_i # We are after expiry: require Tumbler key only
    tx.add_input(BTC::TransactionInput.new( previous_id: @previous_id, # UTXO is "escrow" P2SH funded by Tumbler
                                                  previous_index: @previous_index,
                                                  sequence: 0))
    tx.add_output(BTC::TransactionOutput.new(value: @value , script: key.address.script))
    hashtype = BTC::SIGHASH_ALL
    sighash = tx.signature_hash(input_index: 0,
                                output_script: @puzzle.funding_script,
                                hash_type: hashtype)
    diff = (@tumbler_key.ecdsa_signature(sighash) == @sigma.htb)
    puts "Is sigma equal to T signature ? #{diff}"
    beta = "6337b0ddfa5f17c57936f9e656869abe7f704b7e8cb041c7e16228a23bfc101a"
    good = @tumbler_key.verify_ecdsa_signature(sigma, beta.htb)
    puts "Is sigma a valid Tumbler signature ? #{good}"
    tx.inputs[0].signature_script = BTC::Script.new
    # tx.inputs[0].signature_script << BTC::Script::OP_0
    # tx.inputs[0].signature_script << (@sigma.htb + BTC::WireFormat.encode_uint8(hashtype))  # Tumbler signature
    tx.inputs[0].signature_script << (@tumbler_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))  # Tumbler signature
    # tx.inputs[0].signature_script << (@bob_key.ecdsa_signature(sighash) + BTC::WireFormat.encode_uint8(hashtype))  # Bob signature
    # tx.inputs[0].signature_script << BTC::Script::OP_TRUE   
    tx.inputs[0].signature_script << BTC::Script::OP_FALSE         
    tx.inputs[0].signature_script << @puzzle.funding_script.data
    puts tx
    
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
       params.require(:puzzle).permit(:script_id, :y, :r, :real_indices, :fake_indices, :encrypted_signature, :escrow_txid, :alice_public_key, :bob_public_key, :tumbler_public_key, :expiry_date, :solution)
     end

end