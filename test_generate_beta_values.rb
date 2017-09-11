include Crypto # module in /lib
# include Http
# Fig. 3, steps 1,2,3
# Alice creates 300 values for Tumbler, mixing 15 real values with 285 fake values
  
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

e = $TUMBLER_RSA_PUBLIC_EXPONENT
n = $TUMBLER_RSA_PUBLIC_KEY

salt=Random.new.bytes(128).unpack('H*')[0] # 1024-bit random integer
puts "Salt: #{salt}"
@r_values = []
@ro_values = []

for i in 0..299  # create 300 blinding factors
  if @payment.real_indices.include? i
    @r_values[i]=Random.new.bytes(10).unpack('H*')[0] # "8f0722a18b63d49e8d9a", size = 20 hex char, 80 bits, 10 bytes
    @ro_values[i] = nil
  else
    # salt is same size as y, otherwise Tumbler can easily tell real values from fake values based on the size of s
    @r_values[i]=(Random.new.bytes(10).unpack('H*')[0].to_i(16)*salt.to_i(16) % n).to_s(16)
    @ro_values[i] = @r_values[i]
  end
end

@beta_values = []

# first, compute 15 real beta values
if @payment.y
  @payment.y_received # update state from "initiated" to "step1"
  p = @payment.y.to_i(16) # y = epsilon^^pk,received from Bob
  puts "y: #{@payment.y}"

  for i in 0..299
    m = @r_values[i].to_i(16)
    if @payment.real_indices.include? i
      b = mod_pow(m,e,n)
      beta_value = (p*b) % n
    else
      beta_value = mod_pow(m,e,n)
    end
    @beta_values[i] = beta_value.to_s(16)
  end

  # data = JSON.parse('{"payment[alice_public_key]": "#{@payment.alice_public_key}", "payment[beta_values]": "#{@beta_values}" }')
  # data = {"payment[alice_public_key]" => @payment.alice_public_key, "payment[beta_values]" => "#{@beta_values}"}
  # result = update_request($PAYMENT_UPDATE_API_URL, data)  # http request performed by Http module in /lib
  uri = URI.parse("http://0.0.0.0:3000/api/v1/payment")
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Patch.new(uri.request_uri)
  request.set_form_data({"payment[alice_public_key]" => @payment.alice_public_key, "payment[beta_values]" => "#{@beta_values}"})
  response = http.request(request)
  result = JSON.parse(response.body)

  # get c values from result params and put them in an array
  @c_values = Array.new
  @c_values = result["c_values"]
  @payment.c_values = @c_values
  
  # get h values from result params and put them in an array
  @h_values = Array.new
  @h_values = result["h_values"]
  @payment.h_values = @h_values
  
  @payment.beta_values = @beta_values
  @payment.ro_values = @ro_values
  @payment.r_values = @r_values # 15 real r values to be revealed to Tumbler after step 8
  @payment.beta_values_sent # update state from "step1" to "step3"
  @payment.c_h_values_received # update payment state from "step3" to "step5"
  @payment.save
else
  puts "Before computing beta values, Alice must get y from Bob."
  raise "Before computing beta values, Alice must get y from Bob."
end

# send real indices and 285 (fake) ro values to Tumbler
# ro values are a 300-element array with 15 nil values in it.
uri = URI.parse("http://0.0.0.0:3000/api/v1/payment")
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Patch.new(uri.request_uri)
request.set_form_data({"payment[alice_public_key]" => @payment.alice_public_key, "payment[real_indices]" => "#{@payment.real_indices}", "payment[ro_values]" => "#{@ro_values}"})
response = http.request(request)
result = JSON.parse(response.body)

# Fig 3, step 7
# For 285 fake indices, Alice verifies now that h = H(k), computes s = Dec(k,c) and verifies also that s = ro
@fake_k_values = Array.new
@fake_k_values = result["fake_k_values"]

true_count = 0
j = 0
for i in 0..299
  unless @payment.real_indices.include? i
    if @payment.h_values[i] == @fake_k_values[j].ripemd160.to_hex
      true_count += 1
    else
      puts "k value check failed: "+"#{@fake_k_values[j]}"
      puts j.to_s
      puts "h value check failed: "+"#{@payment.h_values[i]}"
      puts "h should be: "+"#{@fake_k_values[j].ripemd160.to_hex}"
      puts i.to_s
      raise 'An error has occured: check fake k values failed'
    end
    j += 1
  end
end
puts "Number of k values checked successfully: " + true_count.to_s

if true_count != 285
  raise 'Check fake k values failed: mismatch between h and H(k) values.'
end
# Alice now computes s = Dec(k,c) and verifies that s^^pk = beta

@s_values = []
j = 0
for i in 0..299
  unless @payment.real_indices.include? i
    k = @fake_k_values[j]
    c = @payment.c_values[i]
    decipher = OpenSSL::Cipher::AES256.new(:CBC)
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
if true_count != 285
    puts "Mismatch between fake s and ro values."
    raise 'Tumblebit protocol session aborted: mismatch between fake s and ro values'
end
@payment.k_values = @fake_k_values
@payment.fake_k_values_checked # update state from "step5" to "step7"
@payment.save