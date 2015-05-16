require "rubygems"
require "redis"

#uri = URI.parse(ENV["REDISTOGO_URL"])
#uri = URI.parse(URI.encode(ENV["REDISTOGO_URL"].strip))
#$redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

#$redis = Redis.new(:host => 'angelfish.redistogo.com', :port => 10315, :password => "652f4c27327c7cb52ac7042b0fb31ca2")
$redis = Redis.new(:host => 'localhost', :port => 6379)