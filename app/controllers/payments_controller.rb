class PaymentsController < ApplicationController

  include Crypto # module in /lib
  require 'csv'
  require 'btcruby/extensions'
  require 'mechanize'
  require 'digest'
  
  def index
    @payments = Payment.where.not(:key_path => nil).page(params[:page]).order(created_at: :asc)
  end
  
  
  def new
    @payment = Payment.new
    @payment.expiry_date ||= Time.now.utc  # will set the default value only if it's nil
    real_indices = []
    prng = Random.new
    while real_indices.count < 15
      j = prng.rand(0..299)
      unless real_indices.include? j
        real_indices << j
      end
    end
    @payment.real_indices = real_indices.sort
    
    salt = Figaro.env.tumblebit_salt
    index = (salt.to_i + prng.rand(0..99999)) % 0x80000000
    @payment.key_path = "1/#{index}"
  end
  
  
  def create
    @payment = Payment.new(payment_params)
    
    @payment.save
    render "show", notice: 'Payment was successfully created.'
  end
  
  
  def show
    @payment = Payment.find(params[:id])
  end
  
  
  def edit
    @payment = Payment.find(params[:id])
  end
  
  
  def update
    @payment = Payment.find(params[:id])
    if @payment.update_attributes(payment_params)
      if @payment.y and @payment.aasm_state == "initiated"
        @payment.y_received
        @payment.save
      end
      flash[:notice] = "Payment successfully updated."
      render "show"
    else
      flash[:notice] = "There was a problem with this payment update."
      redirect_to payments_url
    end
  end
  
  
  def destroy
    @payment = Payment.find_by_id(params[:id])
    @payment.destroy
    redirect_to payments_path, notice: 'Payment was successfully deleted.'
  end
  
  
  def alice_step_1
    # Fig. 3, steps 1,2,3
    # Alice creates 300 values for Tumbler, mixing 15 real values with 285 fake values
    @payment = Payment.find(params[:id])
    string = @payment.alice_public_key[-32..-1] || @payment.alice_public_key
    
    
    if @payment.real_indices.blank?
      real_indices = []
      prng = Random.new
      while real_indices.count < 15
        j = prng.rand(0..299)
        unless real_indices.include? j
          real_indices << j
        end
      end
      @payment.real_indices = real_indices.sort
      @payment.save # save indices of real values to @payment.real_indices
    end
    puts "Real indices: #{@payment.real_indices}"
    
    # Exponent (part of the public key)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    # The modulus (aka the public key, although this is also used in the private key computations as well)
    n = $TUMBLER_RSA_PUBLIC_KEY
    
    salt=Random.new.bytes(128).unpack('H*')[0] # 1024-bit random integer
    puts "Salt: #{salt}"
    r=[]
    
    for i in 0..299  # create 300 blinding factors

      if @payment.real_indices.include? i
        r[i]=Random.new.bytes(10).unpack('H*')[0] # "8f0722a18b63d49e8d9a", size = 20 hex char, 80 bits, 10 bytes
      else
        r[i]=(Random.new.bytes(10).unpack('H*')[0].to_i(16)*salt.to_i(16) % n).to_s(16) # salt is same size as y, otherwise Tumbler can easily tell real values from fake values based on the size of s
      end
    end
    
    # dump the 285 ro values to a new csv file for Tumbler
    @ro_values = []
    require 'csv'
    file_name = "app/views/products/ro_values_#{string}.csv"
    if File.exists?(file_name)
      File.delete(file_name) # delete any previous version of file
    end
    
    CSV.open(file_name, "ab") do |csv|
      for i in 0..299
        unless @payment.real_indices.include? i
          @ro_values[i] = r[i]
        end
      end
      @ro_values.each do |ro|
        csv << [ro]
        end
      end # of CSV.open (writing to ro_values_123456.csv)
    
    @beta_values = []
    @r_values = []
    # first, compute 15 real beta values
    if @payment.y
      p = @payment.y.to_i(16) # y = epsilon^^pk,received from Bob
      puts "y: #{@payment.y}"
    
      for i in 0..299
        m = r[i].to_i(16)
        if @payment.real_indices.include? i
          @r_values << r[i]
          b = mod_pow(m,e,n)
          beta_value = (p*b) % n
        else
          beta_value = mod_pow(m,e,n)
        end
        @beta_values[i] = beta_value.to_s(16)
      end
    
      # Alice sends the 300 values to Tumbler in a CSV file
      # dump the 300 values to a new csv file for Tumbler
      file_name = "app/views/products/beta_values_#{string}.csv"
      if File.exists?(file_name)
        File.delete(file_name) # delete any previous version of file
      end
    
      CSV.open(file_name, "ab") do |csv|
        @beta_values.each do |beta|
          csv << [beta]
        end
      end # of CSV.open (writing to betavalues123456.csv)
      @payment.beta_values = @beta_values
      @payment.ro_values = @ro_values
      @payment.r_values = @r_values # 15 real r values to be revealed to Tumbler after step 8
      @payment.beta_values_sent # update state to step5
      @payment.save
      render "show"
    else
      redirect_to payments_url, alert: "Before computing beta values, Alice must get y from Bob."
    end
  end # of alice_step_1
  
  
  def alice_step_5
    # send real_indices and ro values to Tumbler
    @payment = Payment.find(params[:id])
    string = @payment.alice_public_key[-32..-1] || @payment.alice_public_key
    
    data = open("app/views/products/c_h_values_#{string}.csv").read
    @c_values = []
    @h_values = []
    j = 0
    CSV.parse(data) do |row|
      c_h_array = []
      row.each do |f|
        c_h_array << f
        @c_values[j] = c_h_array[0]
        @h_values[j] = c_h_array[1]
      end
      j+=1
    end # do |row| (read input file)
    @payment.c_values = @c_values
    @payment.h_values = @h_values
    @payment.save
    
    file_name = "app/views/products/ro_values_#{string}.csv"
    if File.exists?(file_name) and @payment.aasm_state == "step5"
      @payment.c_h_values_received # update state to step7
      @payment.save
    end
  end # of alice_step_5
  
  
  def alice_step_7
    # Fig 3, step 7
    # For 285 fake indices, Alice verifies now that h = H(k), computes s = Dec(k,c) and verifies also that s = ro
    
    @payment = Payment.find(params[:id])
    string = @payment.alice_public_key[-32..-1] || @payment.alice_public_key
    # Alice reads the 285 fake k values from Tumbler's CSV file and verifies that h = H(k)

    data = open("app/views/products/fake_k_values_#{string}.csv").read
    @fake_k_values = []
    j = 0
    CSV.parse(data) do |row|
      fake_k_array = []
      row.each do |f|
        fake_k_array << f
        @fake_k_values[j] = fake_k_array[0]
      end
      j+=1
    end # do |row| (read input file)
    puts "Number of fake k values loaded: " + j.to_s
    
    true_count = 0
    j = 0
    for i in 0..299
      unless @payment.real_indices.include? i
        if @payment.h_values[i] == @fake_k_values[j].ripemd160.to_hex
          true_count += 1
        else
          puts "h: " + @payment.h_values[i]
          puts "k: " + @fake_k_values[j].ripemd160.to_hex
        end
        j += 1
      end
    end
    puts "Number of k values checked successfully: " + true_count.to_s
    
    unless true_count == 285
      redirect_to @payment, alert: "Mismatch between h and H(k) values."
    else
      # Alice now computes s = Dec(k,c) and verifies that s^^pk = beta
      e = $TUMBLER_RSA_PUBLIC_EXPONENT
      n = $TUMBLER_RSA_PUBLIC_KEY

      @s_values = []
      j = 0
      for i in 0..299
        unless @payment.real_indices.include? i
          k = @fake_k_values[j]
          c = @payment.c_values[i]
          decipher = OpenSSL::Cipher::AES.new(128, :CBC)
          decipher.decrypt
          key_hex = k[0..31]
          iv_hex = k[32..63]
          key = key_hex.from_hex
          iv = iv_hex.from_hex
          decipher.key = key
          decipher.iv = iv
          @s_values[i] =  decipher.update(BTC::Data.data_from_hex(c)) + decipher.final
          j += 1
        end
      end
      
      true_count = 0
      for i in 0..299
        unless @payment.real_indices.include? i
          if (@payment.ro_values[i] == @s_values[i])  # verify s = ro (fake values)
            true_count += 1
          end
        end
      end
      puts "Number of s values checked successfully: " + true_count.to_s
      unless true_count == 285
        redirect_to @payment, alert: "Mismatch between fake s and ro values."
      end
      @payment.fake_k_values_received # update state to step8
      @payment.save
      
    end
    
  end # of alice_step_7
  
  
  def alice_step_11
    # TODO: Learn kj from Tsolve spending Tpuzzle funded by Alice in alice_step_7
    @payment = Payment.find(params[:id])

    url_string = $BLOCKR_RAW_TX_URL + @payment.first_spending_tx_hash_unconfirmed
    puts url_string
    @agent = Mechanize.new
    begin
      page = @agent.get url_string
    rescue Exception => e
      page = e.page
    end
    data = page.body
    result = JSON.parse(data)
    @transaction = BTC::Transaction.new(hex: result['data']['tx']['hex'])
    puts "#{result['data']['tx']['hex']}" # raw_tx in hex
    puts @transaction.dictionary['in'][0]['scriptSig']['asm']
    @words = @transaction.dictionary['in'][0]['scriptSig']['asm'].split(/\W+/) # array of real k values revealed by Tumbler
    
    puts "Words=#{@words[0]}"
    @real_k_values = []
    for i in 1..15
			@real_k_values[i-1] = @words[16-i].scan(/../).map { |x| x.hex.chr }.join # convert to hex string
		end
    # Decrypt cj to sj = Hprg(kj) ⊕ cj
    
    # Decrypt 15 real cj to sj = Hprg(kj) ⊕ cj 
    @real_s_values = []
    @real_c_values = @payment.real_c_values
    # Tumbler picked 15 real random symetric encryption key k (128 bits) and computed 
    # c = Enc(k, s) and h = H(k)
    true_count = 0
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    for i in 0..14
      decipher = OpenSSL::Cipher::AES.new(128, :CBC)
      decipher.decrypt
      
      key_hex = @real_k_values[i][0..31] # TODO handle case when k starts with 0 (padding)
      iv_hex = @real_k_values[i][32..63]
      key = key_hex.from_hex
      iv = iv_hex.from_hex
      decipher.key = key
      decipher.iv = iv
      encrypted = @real_c_values[i].from_hex
      @real_s_values[i] = decipher.update(encrypted) + decipher.final # plain
      if (@payment.real_beta_values[i] == mod_pow(@real_s_values[i].to_i(16),e,n).to_s(16))  # verify s**e = beta mod n
        true_count += 1
      end
    end
    
    # Obtain solution sj/rj mod n
    # which is y**d mod N.
    @payment.solution = ((@real_s_values[0].to_i(16)/@payment.r_values[0].to_i(16)) % n).to_s(16)
    if true_count == 15
      @payment.solve_tx_broadcasted # update state from "step8" to "completed"
      @payment.save
      render "show"
    else
      redirect_to @payment, alert: "Mismatch between real s and beta values."
    end
    
  end # of alice_step_11
  
  
  def bob_step_9
    # Tumbler computes 41-quotient RSA-quotient-chain with real epsilon values for Bob (so that Bob can trust real z values)
    @payment = Payment.find(params[:id])
    @script =Script.find(@payment.script_id)
    data = open("app/views/products/epsilon_values_#{@payment.funded_address}.csv").read
    @epsilon_values = []
    j = 0
    CSV.parse(data) do |row|
      epsilon_array = []
      row.each do |f|
        epsilon_array << f
        @epsilon_values[j] = epsilon_array[0]
      end
      j+=1
    end # do |row| (read input file)
    puts "Number of epsilon values in file: " + j.to_s
    n = $TUMBLER_RSA_PUBLIC_KEY  # modulus
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    fake = []
    @payment.fake_indices.each do |ri|
      fake << ri.strip # avoid problems with extra leading or trailing space caracters
    end
    @real_epsilon_values = []
    for i in 0..83
      unless fake.include? i.to_s
        @real_epsilon_values << @epsilon_values[i]
      end
    end
    puts "Number of real epsilon values : " + @real_epsilon_values.count.to_s
    puts @real_epsilon_values
    @quotient = []
    @z = []
    j = 0
    for i in 0..40
      num = @real_epsilon_values[i+1].to_i(16)
      den = invmod(@real_epsilon_values[i].to_i(16),n)
      @quotient[i] = num*den % n
      puts "Quotient : " + @quotient[i].to_s
      
      @z[i] = mod_pow(@real_epsilon_values[i].to_i(16), e, n)
      @z[i+1] = mod_pow(@real_epsilon_values[i+1].to_i(16), e, n)

      if ((@z[i]*mod_pow(@quotient[i], e, n) % n) == @z[i+1])
        j += 1
      else
        puts "Fail, should equal zero: " + ((@z[i]*mod_pow(@quotient[i], e, n) % n) == @z[i+1]).to_s
      end
      
    end
    puts j
    # dump 41 quotient values to csv file for Bob
    file_name = "app/views/products/quotient_values_#{@payment.funded_address}.csv"
    if File.exists?(file_name)
      File.delete(file_name) # delete any previous version of file
    end

    CSV.open(file_name, "ab") do |csv|
      @quotient.each do |f|
        unless (f == "0" or f.nil?)
          csv << [f]
        end
      end
    end # of CSV.open (writing to csv file)
    # to remove annoying last (empty) line from file:
    File.truncate(file_name, File.size(file_name) - 1)
    
  end
  
  
  def create_blinding_factors
    # Fig. 3, steps 1,2,3
    # Alice creates 300 values for Tumbler, mixing 15 real values with 285 fake values
    @payment = Payment.find(params[:id])
    @script =Script.find(@payment.script_id)
    string = @payment.funded_address
    
    if @payment.real_indices.blank?
      real_indices = []
      prng = Random.new
      while real_indices.count < 15
        j = prng.rand(0..299)
        unless real_indices.include? j
          real_indices << j
        end
      end
      @payment.real_indices = real_indices
      @payment.save # save indices of real values to @payment.real_indices
    end
    puts "Real indices: #{@payment.real_indices}"
    
    # Exponent (part of the public key)
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    # The modulus (aka the public key, although this is also used in the private key computations as well)
    n = $TUMBLER_RSA_PUBLIC_KEY
    
    salt=Random.new.bytes(32).unpack('H*')[0] # 256-bit random integer
    puts "Salt: #{salt}"
    r=[]
    real = []
    @payment.real_indices.each do |ri|
      real << ri.strip # avoid problems with extra leading or trailing space caracters
    end
    
    for i in 0..299  # create 300 blinding factors
      # 285 ro values created by Alice
      # 15 r values created by Bob. Alice knows only d = y*r^^pk
      if real.include? i.to_s
        r[i]=Random.new.bytes(10).unpack('H*')[0] # "8f0722a18b63d49e8d9a", size = 20 hex char, 80 bits, 10 bytes
      else
        r[i]=(Random.new.bytes(10).unpack('H*')[0].to_i(16)*salt.to_i(16) % n).to_s(16) # salt is same size as epsilon, otherwise Tumbler can easily tell real values from fake values based on the size of s
      end
    end
    
    
    # dump the 285 values to a new csv file for Tumbler
    @ro_values = []
    require 'csv'
    # string = OpenSSL::Digest::SHA256.new.digest(@payment.id.to_s).unpack('H*').first[0..5]
    file_name = "app/views/products/ro_values_#{string}.csv"
    if File.exists?(file_name)
      File.delete(file_name) # delete any previous version of file
    end
    
    CSV.open(file_name, "ab") do |csv|
      for i in 0..299
        unless real.include? i.to_s
          @ro_values[i] = r[i]
        end
      end
      @ro_values.each do |ro|
        csv << [ro]
        end
      end # of CSV.open (writing to ro_values_123456.csv)
    
    @beta_values = []
    # first, compute 15 real beta values

    p = @payment.y.to_i  # y = epsilon^^pk
    # The secret exponent (aka the private key)
    d = Figaro.env.tumbler_rsa_private_key.to_i(16)
    epsilon = mod_pow(p,d,n)
    puts "y: #{@payment.y.to_i.to_s(16)}"
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
    file_name = "app/views/products/beta_values_#{string}.csv"
    if File.exists?(file_name)
      File.delete(file_name) # delete any previous version of file
    end
    
    CSV.open(file_name, "ab") do |csv|
      @beta_values.each do |beta|
        csv << [beta]
        end
      end # of CSV.open (writing to betavalues123456.csv)
    
  end
  
  
  def alice_step_4
    # Fig. 3, step 4: tumbler_encrypts_values
    @payment = Payment.find(params[:id])
    # @script =Script.find(@payment.script_id)
    
    # Tumbler reads the 300 values from Alice's CSV file
    # then, Tumbler computes beta^^sk = s for each of the 300 beta values
    row_count = 0
    string = @payment.hash_address
    data = open("app/views/products/beta_values_#{string}.csv").read
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
    file_name = "app/views/products/s_values_#{string}.csv"
    if File.exists?(file_name)
      File.delete(file_name) # delete any previous version of file
    end
    
    CSV.open(file_name, "ab") do |csv|
      @s_values.each do |s|
        csv << [s]
        end
      end # of CSV.open (writing to s_values_123456.csv)
      
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
        redirect_to @payment, alert: "Problem with signature encryption."
      end
    end
    
    @payment.k_values = @k_values
    @payment.c_values = @c_values
    @payment.h_values = @h_values
    @payment.c_h_values_received # update state to step5
    @payment.save
    
    # dump the 300 (c, h) couples to a new csv file for Alice
    file_name = "app/views/products/c_h_values_#{string}.csv"
    if File.exists?(file_name)
      File.delete(file_name) # delete any previous version of file
    end
    
    CSV.open(file_name, "ab") do |csv|
      for i in 0..299
        csv << [@c_values[i],@h_values[i]]
        end
      end # of CSV.open (writing to chvalues123456.csv)
      
    # dump the 300 k values to a new csv file for Tumbler to keep
    file_name = "app/views/products/k_values_#{string}.csv"
    if File.exists?(file_name)
      File.delete(file_name) # delete any previous version of file
    end

    CSV.open(file_name, "ab") do |csv|
      for i in 0..299
        csv << [@k_values[i]]
        end
      end # of CSV.open (writing to k_values_123456.csv)
    
  end # of alice_step_4
  
  
  def alice_step_6
    
    # tumbler_checks_ro_values
    @payment = Payment.find(params[:id])
    # @script =Script.find(@payment.script_id)
    # string = OpenSSL::Digest::SHA256.new.digest(@payment.id.to_s).unpack('H*').first[0..5]
    string = @payment.funded_address
    row_count = 0
    data = open("app/views/products/ro_values_#{string}.csv").read
    @ro_values = []
    @payment.real_indices = []
    # Tumbler reads file with 285 "fake" ro values
    require 'csv'
    CSV.parse(data) do |row|
      if row.blank?
        @payment.real_indices << row_count.to_s
      else
        row.each do |ro|
          @ro_values << ro
        end
      end
      row_count+=1
    end # do |row| (read input file)
    puts "Number of ro values in file: " + row_count.to_s
    puts "Number of real indices: " + @payment.real_indices.count.to_s
    @payment.save
    # Tumbler verifies beta = ro^^pk for all ro values
    e = $TUMBLER_RSA_PUBLIC_EXPONENT
    n = $TUMBLER_RSA_PUBLIC_KEY
    
    # Tumbler reads the 300 beta values from Alice's CSV file
    # then, Tumbler computes ro^^pk for each of the 285 ro values
    # finally, Tumbler verifies beta = ro^^pk for all ro values
    row_count = 0
    data = open("app/views/products/beta_values_#{string}.csv").read
    @beta_values = []
    CSV.parse(data) do |row|
      row.each do |beta|
        @beta_values << beta.to_i(16)
      end
      row_count+=1
    end # do |row| (read input file)
    puts "Number of beta values in file: " + row_count.to_s
    
    real = []
    @payment.real_indices.each do |ri|
      real << ri.strip # avoid problems with extra leading or trailing space caracters
    end
    
    true_count = 0
    for i in 0..299
      unless real.include? i.to_s
        ro = @ro_values.shift.to_i(16)  # TODO fix bug here !
        if (@beta_values[i] == mod_pow(ro,e,n))
          true_count+=1
        end
      end
    end
    puts "Number of ro values checked: " + true_count.to_s
    
    unless true_count == 285
      redirect_to @payment, alert: "Invalid ro values."
    else
      # Tumbler reads k values from his csv file
      data = open("app/views/products/k_values_#{string}.csv").read
      @k_values = []
      CSV.parse(data) do |row|
        row.each do |k|
          @k_values << k
        end
      end # do |row| (read input file)
      
      file_name = "app/views/products/fake_k_values_#{string}.csv"
      # dump the 285 "fake" k values to a new csv file for Tumbler to send to Alice
      if File.exists?(file_name)
        File.delete(file_name) # delete any previous version of file
      end

      CSV.open(file_name, "ab") do |csv|
        for i in 0..299
          unless real.include? i.to_s
            csv << [@k_values[i]]
          end
        end
      end
      File.truncate(file_name, File.size(file_name) - 1)
      # Tumbler sends csv file with 285 k values (encryption keys) to Alice: TODO download button in view
    end
    
  end # of alice_step_6
  
  
  def alice_step_9
    # Tumbler gets y and r_values file from Alice
    # Tumbler verifies real beta_values = y·(r)^^e mod n for real r values
    # If not, abort.
    # if all real beta values unblind to y, Tumbler post transaction Tsolve containing 15 real k values
  end


  private
 
     def payment_params
       params.require(:payment).permit(:solution, :title, :y, :r_values, :beta_values, :ro_values, :k_values,:real_indices,:c_values, :h_values,:key_path, :tumbler_public_key, :expiry_date, :aasm_state)
     end

end