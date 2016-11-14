# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

Post.delete_all

Post.create(
  id: 3,
  title: "About",
  published_at: Time.now,
  body: 
  %Q{### About bitcoinscri.pt

    A standard Bitcoin address works like a digital vault. There are one or more keys that allow key holders to release the coins by opening the vault.
    In addition to standard addresses, a certain type of Bitcoin addresses, known as Pay-to-Script-Hash or P2SH, require the knowledge of a redeem script.
    
    The redeem script is a set of conditions that must be met to unlock the coins locked in a previous transaction funding the P2SH address.
    The redeem script must be written in a stack-based [scripting language](https://en.bitcoin.it/wiki/Script#Words) specified in the Bitcoin core protocol. 
    In a way, the redeem script is like the digital vault owner's manual: without it, the key holders would be unable to open the vault with their keys.
    
    With the Bitcoin network acting as a distributed timestamp server on a peer-to-peer basis, a Bitcoin script can set time conditions for opening a vault.
    Hence, a P2SH address can be thought of as a digital vault connected to a tamper-proof clock.
    
    This application allows users to create transactions using the Bitcoin scripting language.

    Need help? Contact me at pierre dot noizat at paymium dot com

    If the application doesn't work as expected, please report an issue.
    and include the diagnostics.

    This application was developped using the following free software:
    
    * Ruby 2.3.0
    * Rails 4.2.0
    * [btcruby](https://github.com/oleganza/btcruby), the awesome Bitcoin ruby library developped by Oleg Andreev and Ryan Smith.}
)

Post.create(
  id: 4,
  title: "Getting started",
  published_at: Time.now,
  body:
  %Q{### Getting Started with Bitcoin Scripts

    To create a new script, select one amongst the available scripts and give it a name. 

    Once your script is created, fill in the required parameters, typically one or more public keys and date/time values.
    
    To generate your own Bitcoin public/private key pairs, I recommend [bitaddress.org](https://bitaddress.org)
    
    Once this first step is completed, the application will display the corresponding P2SH address.
    
    If the P2SH address is funded, the application will allow you to sign a transaction spending the funds to another address supplied by you. 
    
    The coins can be spent by supplying the required private keys. Then you can broadcast the spending transaction to the Bitcoin network.
    
    Depending on the set time conditions, the network will either reject the signed spending transaction as non-final or confirm it.
    
    If the time conditions are not met, the network nodes will return an error message like "Locktime requirement not satisfied".
    
    More scripts will be added over time after being carefully tested.
    
    To suggest a new script, drop me a note via email at pierre dot noizat at paymium dot com.

    }
)

Post.create(
  id: 5,
  title: "License",
  published_at: Time.now,
  body:
  %Q{### License

    © Pierre Noizat - Paymium 2014-2016 Soon to be released under the [MIT license](http://opensource.org/licenses/mit-license.php)}
)

Post.create(
  id: 6,
  title: "Timelocked Address",
  published_at: Time.now,
  body: 
  %Q{### Timelocked Address 
  
  This very simple script sets an expiry date and public key that must be matched to unlock the funds. 
  
  The funds cannot move from the time locked address until the set expiry date and time. 
  
  After the expiry, a single private key, corresponding to the set public key, is required.
  
  **Script**:
  `<expiry time> CHECKLOCKTIMEVERIFY DROP <public key> CHECKSIG`
  
  **Example**:
  
  Expiry: 2016-11-13 15:28:44 UTC
  
  Public Key: 023927B837A922696836E26399F759965328437F93AAFAF3E02767D22860C0FBA7
  
  Timelocked Address: 3AMdSGWdRwvaTbsDqFn4s35P3HLf8NKJ6U

  }
)

Post.create(
  id: 7,
  title: "Timelocked 2FA",
  published_at: Time.now,
  body: 
  %Q{### Timelocked 2FA 
  
  The Script requires two keys before the set expiry date and only one key after the expiry date. 
  
  If one of the keys is yours and the other belongs to a 2FA (2FA stands for two-factor authentication) service provider, the funds can be accessed after the expiry date even if the 2FA service provider has disappeared.
  
  **Script**:```
  IF <service public key> CHECKSIGVERIFY
  ELSE <expiry time> CHECKLOCKTIMEVERIFY DROP 
  ENDIF
  <user public key> CHECKSIG
  ```
  
  **Example**:
  
  Expiry: 2020-11-13 17:15:00 UTC
  
  Escrow Service (Compressed) Public Key: 02259B57015E60DE464E1D83C375BDD01D272290C51CEDE0B794301DE1B7770C7B
  
  User (Compressed) Public Key: 023927B837A922696836E26399F759965328437F93AAFAF3E02767D22860C0FBA7
  
  Timelocked 2FA Address: 3NSn5VE22WEMgyxqyojW9mjxhSV6q1sNyC
  
  }
)

Post.create(
  id: 8,
  title: "Contract Oracle",
  published_at: Time.now,
  body: 
  %Q{### Contract Oracle 
  
  An external data source can be linked to a P2SH address with a certain value set in the script. 
  
  The script requires two keys to unlock the funds, one key held by the beneficiary, the other key held by a trusted Oracle whose job is to validate that the value conditions are met.
  
  **Script**:
  `<contract_hash> DROP 2 <beneficiary pubkey> <oracle pubkey> 2 CHECKMULTISIG`
  
  **Example**:
  
  Contract hash: cd6c5f44e130f979874b87f11562d8dc1e73bd3a83d666e3a66de681a0e1cb2e
  
  Beneficiary (Compressed) Public Key: 023927B837A922696836E26399F759965328437F93AAFAF3E02767D22860C0FBA7
  
  Oracle (Compressed) Public Key: 02259B57015E60DE464E1D83C375BDD01D272290C51CEDE0B794301DE1B7770C7B
  
  Oracle Contract Address: 3Qr7QGxKLosD3RsRB96BpMx9vFb2rpNtm5
  
  }
)

Post.create(
  id: 9,
  title: "Hashed Timelocked Contract",
  published_at: Time.now,
  body: 
  %Q{### Hashed Timelocked Contract 
  
  Hashed Timelock Contract (HTLC) as proposed in the Lightning Network white paper.
  
  The receiver can include a 0 or 1 in the scriptSig to choose to enter through if or else branch.
  
  **Script**:```
  IF
  HASH160 <hash160(S)> EQUALVERIFY
  2 <AlicePubkey1> <BobPubkey1>
  ELSE
  2 <AlicePubkey2> <BobPubkey2>
  ENDIF
  2 CHECKMULTISIG
  ```
  
  **Example**:
  
  hash160(S): ee9eb446302cbaaeded21f6a50d7ffb6c240023d
  
  Alice Public Key 1: 02BE332AE534CC30FB84BA64817A748DBC9A9C9021463A645F5B3CF2AB4AEB0284

  Bob Public Key 1: 039DD14C371FBB1BCA9860942D14ED32897CF4ABF8312A6446EBF716774769441B


  Alice Public Key 2: 02808F45C3B1DEF4C9917D80ABD94D1DA271069C1CE227F8FA6D57E7D5FA836838

  Bob Public Key 2: 03C875B4E83368088CB5C9EA1244F16679A091277F7C3BA771E83673DA3A839BD8
  
  Hashed Timelocked Contract Address: 3LZgKZspe411v9vNGFddNMQZqGdzeTvd2Q

  }
)

Post.create(
  id: 10,
  title: "Opcodes",
  published_at: Time.now,
  body:
  %Q{### Scripts and opcodes

    Bitcoin scripts use a limited set of approximately 250 Script words, also known as opcodes.
    
    This deliberate limitation allows formal verification of the scripts to reduce the risk of bugs.
    
    A very clear documentation of frequently used opcodes can be found [here](https://bitcoin.org/en/developer-reference#opcodes).
    
    For an exhaustive list and documentation of the current opcodes, visit the [Bitcoin wiki page](https://en.bitcoin.it/wiki/Script#Words).

    }
)