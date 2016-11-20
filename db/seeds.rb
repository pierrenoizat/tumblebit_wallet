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
    Need bitcoins ? Sign up at [paymium.com](https://paymium.com) !

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
    
    If you enter the wrong private key in the transaction signing form, your signed transaction can be broadcast but you are likely to get an error message from the network like "Script evaluated without error but finished with a false/empty top stack element".
    
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

    © Pierre Noizat - Paymium 2015-2016 Soon to be released under the [MIT license](http://opensource.org/licenses/mit-license.php)}
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
  
  **Use case**:
  To establish a payment channel between Alice and Bob, Alice will fund a 2-of-2 hashed timelocked contract address requiring Bob's key and her key.
  Alice will then ask Bob to sign a refund transaction spending the 2-of-2 address to her timelocked address. 
  The payment channel will be open as long as Alice does not broadcast her timelocked refund transaction.
  
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
  
  **Use case**:
  A self-executing insurance contract can be written by the insurance company and a user, both trusting an oracle to check an external data source.
  For example, the insurance contract can be a promise to indemnify the user if a flight is canceled.
  Because the script includes a hash of the contract terms, the oracle signature of a transaction spending the Oracle Contract address to the user address is the oracle testimony that the flight was indeed canceled.  
  
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
  
  **Use case**:
  Alice wants to send money to Chuck via the Lightning Network. Bob is a trustless payment hub on the network.
  Chuck chooses an arbitrary secret S and sends hash160(S) to Alice.
  Alice sends money to the HTLC address. 
  
  Bob signs with his key 2 a transaction spending the HTLC address to a timelocked refund address controlled by Alice.
  Alice signs with her key 1 a transaction spending the HTLC address to pay Bob.
  Bob can collect the payment before the expiry of the timelock T1 if and only if he knows S.
  
  A similar HTCL address is created by Bob and Chuck with a timelock T2 < T1. Bob funds the HTLC address.
  A similar set of transactions are signed by Bob and Chuck.
  Alice does not broadcast her refund transaction because doing so would prompt Bob to do the same with his refund transaction, closing the payment channel immediately.
  Chuck reveals S on the blockchain when he collects his payment. Knowing S, Bob can collect his payment, completing the protocol.
  If Chuck fails to collect his payment before T2, Bob can collect his refund. If Bob fails to collect his payment before T1, Alice can collect her refund.
  
  
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

Post.create(
  id: 11,
  title: "Smart Contracts",
  published_at: Time.now,
  body:
  %Q{### Smart Contracts

    _A smart contract is an event driven program, with state, which runs on a replicated, shared ledger and which can take custody over assets on that ledger_.
    This definition proposed by T. Swanson in 2015 assumes that the program implementing the smart contract must or should run entirely on-chain.
    
    In fact, most transactions in any contract happen off-chain. Goods or services are delivered by Bob to Alice in exchange for a payment sent by Alice.
    The payment part belongs to the blockchain while the delivery can only be witnessed by the parties, i.e by Alice, Bob and any number of arbitrators they choose to trust.
    
    As a result, a smart contract can be defined also as a payment protocol involving on-chain and off-chain transactions as well as external sources of data.
    
    Because, the program inputs include one or more centralized source of data that the blockchain is unaware of, there is no point in mandating that the entire program execution happen on a decentralized network.
    Instead, for efficiency, only the relevant part of the program, i.e in most cases the payment transactions, should be executed as chaincode. 
    
    Hence I propose a more generic definition: _A smart contract is a payment protocol that can be implemented as an event driven program, with state, including some chaincode_.

    }
)

Post.create(
  id: 12,
  title: "CHECKLOCKTIMEVERIFY",
  published_at: Time.now,
  body: 
  %Q{### CHECKLOCKTIMEVERIFY 
  
    **Word**: `OP_CHECKLOCKTIMEVERIFY` ( previously `OP_NOP2` )
    **Opcode**: 177	
    **Hex**: 0xb1
  
    CHECKLOCKTIMEVERIFY (CLTV) marks transaction as invalid if the top stack item is greater than the transaction's nLockTime field, otherwise script evaluation continues as though an OP_NOP was executed. 
    Transaction is also invalid if 1. the stack is empty; or 2. the top stack item is negative; or 3. the top stack item is greater than or equal to 500000000 while the transaction's nLockTime field is less than 500000000, or vice versa; or 4. the input's nSequence field is equal to 0xffffffff. 
    The precise semantics are described in Peter Todd's BIP 65.
  
    A transaction spending from a CLTV output can only be broadcast AFTER the time lock has expired.
    Network nodes will reject it if it is broadcast before the time lock expiry, with a _Locktime requirement not satisfied_ error message.
    Unlike CHECKSEQUENCEVERIFY which sets a relative locktime, CLTV locks bitcoins up until a specific, absolute time in the future.
  
  }
)

Post.create(
  id: 13,
  title: "CHECKSEQUENCEVERIFY",
  published_at: Time.now,
  body: 
  %Q{### CHECKSEQUENCEVERIFY
    
    **Word**: `OP_CHECKSEQUENCEVERIFY` ( previously `OP_NOP2` )
    **Opcode**: 178
    **Hex**: 0xb2
  
    CHECKSEQUENCEVERIFY (CSV) marks transaction as invalid if the relative lock time of the input (enforced by BIP 68 with nSequence) is not equal to or longer than the value of the top stack item. 
    The precise semantics are described in BIP 112.
    BIP 68 introduces relative lock-time consensus-enforced semantics of the sequence number field to enable a signed transaction input to remain invalid for a defined period of time after confirmation of its corresponding outpoint.
    BIP112 (soft fork to enforce CSV) allows users to make bitcoins unspendable for a period of time, much like CheckLockTimeVerify (CLTV), but with a **relative** timelock. 
    Whereas CLTV locks bitcoins up until a specific, absolute time in the future, CSV locks bitcoins up for a specific amount of time after the CSV transaction is included in a block.
    
    If the sequence number field is filled in, require the output being spent to have a relative minimum height.
    e.g a sequence number 200 means there must be at least 200 blocks between the block including the parent transaction and the block includng the child tx. 
    This allows the creation of revocable outputs bearing increasing sequence number.
    
    Bitcoin transactions currently may specify a locktime indicating when they may be added to a valid block.
    Blocks must have a block header time greater than the locktime specified in any transaction in that block.
    Miners get to choose what time they use for their header time but no node will accept a block whose time is more than two hours in the future. 
    This creates a incentive for miners to set their header times to future values in order to include locktimed transactions which weren’t supposed to be included for up to two more hours.
    The consensus rules also specify that valid blocks may have a header time greater than that of the median of the 11 previous blocks. 
    This GetMedianTimePast() time has a key feature we generally associate with time: it can’t go backwards.
    BIP113 specifies a soft fork enforced in the Bitcoin Core 0.12.1 release that weakens this perverse incentive for individual miners to use a future time by requiring that valid blocks have a computed GetMedianTimePast() greater than the locktime specified in any transaction in that block.
    Mempool inclusion rules currently require transactions to be valid for immediate inclusion in a block in order to be accepted into the mempool. 
    The Bitcoin Core 0.12.1 release begins applying the BIP113 rule to received transactions, so transaction whose time is greater than the GetMedianTimePast() will no longer be accepted into the mempool.
    Implication for miners: you will begin rejecting transactions that would not be valid under BIP113, which will prevent you from producing invalid blocks when BIP113 is enforced on the network. 
    Any transactions which are valid under the current rules but not yet valid under the BIP113 rules will either be mined by other miners or delayed until they are valid under BIP113.
    Implication for users: GetMedianTimePast() always trails behind the current time, so a transaction locktime set to the present time will be rejected by nodes running this release until the median time moves forward. 
    To compensate, subtract one hour (3,600 seconds) from your locktimes to allow those transactions to be included in mempools at approximately the expected time.

  }
)

Post.create(
  id: 14,
  title: "EQUALVERIFY",
  published_at: Time.now,
  body: 
  %Q{### EQUALVERIFY
    
    **Word**: `OP_EQUALVERIFY`
    **Opcode**: 136
    **Hex**: 0x88
  
    EQUALVERIFY, predictably, runs EQUAL, then VERIFY.
    EQUAL returns 1 if the inputs are exactly equal, 0 otherwise.
    VERIFY marks transaction as invalid if top stack value is not true.

  }
)

Post.create(
  id: 15,
  title: "CHECKSIGVERIFY",
  published_at: Time.now,
  body: 
  %Q{### CHECKSIGVERIFY
    
    **Word**: `OP_CHECKSIGVERIFY`
    **Opcode**: 173
    **Hex**: 0xad
  
    CHECKSIGVERIFY, predictably, runs CHECKSIG, then VERIFY.
    CHECKSIG: The entire transaction's outputs, inputs, and script are hashed. 
    The signature used by CHECKSIG must be a valid signature for this hash and public key. If it is, 1 is returned, 0 otherwise.
    VERIFY marks transaction as invalid if top stack value is not true.

  }
)