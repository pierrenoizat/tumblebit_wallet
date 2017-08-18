include Crypto # module in /lib
e = $TUMBLER_RSA_PUBLIC_EXPONENT
n = $TUMBLER_RSA_PUBLIC_KEY
@quotient = []
# @num = []
# @denum = []
@quotient = result["quotients"]
puts "Number of quotient values: " + "#{@quotient.count}"

@z_values = []
@z_values = result["z_values"]

puts "Number of z values: " + "#{@z_values.count}"

@real_z_values = []
for i in 0..83
if @payment_request.real_indices.include? i
@real_z_values << @z_values[i]
end
end
puts "Number of real z values : " + @real_z_values.count.to_s
puts "check that z2 = z1*(q2)^pk mod n"

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
y = @real_z_values[0].to_i(16)*mod_pow(@payment_request.r.to_i, e, n) % n
@payment_request.y = y.to_s(16)
# @payment_request.escrow_tx_broadcasted
@payment_request.save
puts 'Tumblers RSA quotients were successfully checked by Bob.'
else
puts j
end