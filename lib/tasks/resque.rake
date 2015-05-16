require 'resque/tasks'
require 'resque/server'

task "resque:setup" => :environment do
  ENV['QUEUE'] = '*'
end

desc "Alias for resque:work (To run workers on Heroku)"
task "jobs:work" => "resque:work"