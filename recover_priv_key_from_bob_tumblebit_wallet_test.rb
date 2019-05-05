@payment_requests = PaymentRequest.all
@payment_requests.each do |payment_request|
 keychain = BTC::Keychain.new(xprv:Figaro.env.bob_msk)
 i = payment_request.real_indices.first
 path = payment_request.key_path
 path ||= "1"
 path = path[0...-2] + i.to_s
 if BTC::Key.new(public_key:BTC.from_hex(keychain.derived_keychain(path).key.public_key.unpack('H*')[0])).address.to_s == "16xgoSrGkG3z6eddGr3m4iqoBDTFWuV6J4"
   puts BTC::Key.new(public_key:BTC.from_hex(keychain.derived_keychain(path).key.public_key.unpack('H*')[0])).address.to_s
	
   puts BTC::Key.new(public_key:BTC.from_hex(keychain.derived_keychain(path).key.public_key.unpack('H*')[0])).to_wif
   puts keychain.derived_keychain(path).key.to_wif
 end
 puts BTC::Key.new(public_key:BTC.from_hex(keychain.derived_keychain(path).key.public_key.unpack('H*')[0])).address.to_s
end