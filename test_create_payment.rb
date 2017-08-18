@payment=Payment.new
@payment.expiry_date  ||= Time.now.utc  # will set the default value only if it's nil
real_indices = []
prng = Random.new
while real_indices.count < 15
j = prng.rand(0..299)
unless real_indices.include? j
real_indices << j
end
end
@payment.real_indices ||= real_indices.sort

salt = Figaro.env.tumblebit_salt
index = (salt.to_i + prng.rand(0..99999)) % 0x80000000
@payment.key_path = "1/#{index}"
@payment.save
uri = URI.parse("http://0.0.0.0:3000/api/v1/payment")
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.request_uri)
request.set_form_data({"payment[alice_public_key]" => @payment.alice_public_key})
response = http.request(request)
result = JSON.parse(response.body)
@payment.tumbler_public_key=result["tumbler_public_key"]
@payment.save