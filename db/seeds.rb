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

    To create a new script, select a script amongst the available script categories. 

    Once a script is selected, fill in the required parameters, typically one or more public keys and time values.
    
    Parameters must be entered in their order of appearance in the script.
    
    Once this first step is completed, the application will display the corresponding P2SH address.
    
    If the P2SH address is funded, the coins can be spent by supplying the required private keys.
    
    The application will build the signed transaction that can be broadcast to the Bitcoin network.
    
    Depending on the set time conditions, the network will either confirm or reject the signed spending transaction.
    
    If the time conditions are not met, the network nodes will return an error message like "Locktime requirement not satisfied".
    
    New script categories will be added over time after being carefully tested.
    
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