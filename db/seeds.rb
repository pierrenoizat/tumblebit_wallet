# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

Post.delete_all

Post.create(
  id: 1,
  title: "My Very First Post",
  published_at: Time.now - 1.day,
  body: 
  %Q{### There Is Something You Should Know!

  This is my very first post using markdown!

  How do you like it?  I learned this from [RichOnRails.com](http://richonrails.com/articles/rendering-markdown-with-redcarpet)!}
)

Post.create(
  id: 2,
  title: "My Second Post",
  published_at: Time.now,
  body: 
  %Q{### My List of Things To Do!

  Here is the list of things I wish to do!
  
  * write more posts
  * write even more posts
  * write even more posts!}
)

Post.create(
  id: 3,
  title: "About",
  published_at: Time.now,
  body: 
  %Q{### About bitcoinscri.pt

    A standard Bitcoin address works like a digital vault. There are one or more keys that allow key holders to release the coins by opening the vault.
    In addition to standard addresses, a certain type of Bitcoin addresses, known as Pay-to-Script-Hash or P2SH, require the knowledge of a redeem script.
    
    The redeem script is a set of conditions that must be met to unlock the coins locked in a previous transaction funding the P2SH address.
    The redeem script must be written in a stack-based scripting language specified in the Bitcoin core protocol. 
    In a way, the redeem script is like the digital vault owner's manual: without it, the key holders would be unable to open the vault with their keys.
    
    With the Bitcoin network acting as a distributed timestamp server on a peer-to-peer basis, a Bitcoin script can set time conditions for opening a vault.
    Hence, a P2SH address can be thought of as a digital vault connected to a tamper-proof clock.
    
    This application allows users to create transactions using the Bitcoin scripting language.

    Need help? Contact me at pierre dot noizat at paymium dot com

    If the application doesn't work as expected, please report an issue.
    and include the diagnostics.

    This application requires:

    - Ruby 2.3.0
    - Rails 4.2.0
    - btcruby, the awesome Bitcoin ruby library developped by Oleg Andreev and Ryan Smith.}
)

Post.create(
  id: 4,
  title: "Getting started",
  published_at: Time.now,
  body:
  %Q{### Getting Started with Bitcoin Scripts

    To create a new script, select one amongst the available scripts and give it a name. 

    Once your script is created, fill in the required parameters, typically one or more public keys and date/time values.
    
    Once this first step is completed, the application will display the corresponding P2SH address.
    
    If the P2SH address is funded, the application will allow you to sign a transaction spending the funds to another address supplied by you. 
    
    The coins can be spent by supplying the required private keys. Then you can broadcast the spending transaction to the Bitcoin network.
    
    Depending on the set time conditions, the network will either reject the signed spending transaction as non-final or confirm it.
    
    If the time conditions are not met, the network nodes will return an error message like "Locktime requirement not satisfied".
    
    More scripts will be added over time after being carefully tested.
    
    To suggest a new script, drop me a note via emaiL at pierre dot noizat at paymium dot com.

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
  
  After the expiry, a single private key is required.

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

  }
)