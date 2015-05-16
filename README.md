Rails Omniauth App
================

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

This application allows users to create and navigate a binary tree build from an account list uploaded to AWS S3.

Problems? Issues?
-----------

Need help? Contact me at pierre dot noizat at paymium dot com

If the application doesn't work as expected, please [report an issue](https://github.com/RailsApps/rails_apps_composer/issues)
and include the diagnostics.

Ruby on Rails
-------------

This application requires:

- Ruby 2.2.0
- Rails 4.2.0

Getting Started
---------------
To create a new binary tree, upload a CSV file of your account list.
Each account is on a new line with: name, credit
Make sure to NOT add an empty line at the end of your file as this would cause the line count to be incremented, messing up the computation of the tree.

License
-------
DWTFYW License