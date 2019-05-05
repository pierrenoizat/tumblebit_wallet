Tumblebit.network Wallet
================

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

This Bitcoin wallet application allows users to create and send unlinkable Bitcoin transactions to and from a Tumblebit server.
This application is for experimental, non-commercial use only.
Do NOT use it to move any significant amount of money.
The application can run locally and be tested against my tumblebit demo server at [tumnblebit.network](tumblebit.network)

Problems? Issues?
-----------

Need help? Contact me at pierre dot noizat at paymium dot com

If the application doesn't work as expected, please [report an issue](https://github.com/RailsApps/rails_apps_composer/issues)
and include the diagnostics.

Ruby on Rails
-------------

This application requires:

- Ruby 2.3.0
- Rails 4.2.0
- btcruby

Getting Started
---------------
$ rvm use 2.3.0
$ pg_ctl -D /usr/local/var/postgres start
$ ssh-add ~/.ssh/yourname
$ rails s

:start to :step1
First, Bob creates payment request on his wallet: gives it a (optional) title and hit “Start Request Creation”.

:step1 to :step2
Tumbler sets expiry and responds with P2SH address. Tumbler admin gets notified of the creation (TODO) and funds escrow_tx.

Bob visits his payment request page on his wallet and can now hit “submit payment request to Tumbler” button.
The page displays a puzzle for Bob to send to Alice.

Upon receiving puzzle from Bob, Alice creates a payment on her wallet by hitting the “Start payment process” button.
She can now paste the puzzle on her payment page and hit the “Start Payment Process with Tumbler” button.
She funds the payment adress.

Tumbler admin gets notified of Alice payment (TODO), visits his payment page and displays the tx solve paying him.
Tumbler broadcasts the tx.
Alice now sees her puzzle solution on her payment page and sends it to Bob.

Bob pastes the solution on his payment request page and hit “Check solution” button. If the check is ok, the page now displays the tx paying Bob. Bob gets paid by broadcasting his payout tx.
That’s all folks !


License
-------
© Pierre Noizat 2015-2019 Released under the [MIT license](http://opensource.org/licenses/mit-license.php)