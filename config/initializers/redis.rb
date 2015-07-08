$redis = Redis.new(YAML::load_file(File.join(Rails.root, 'config/redis.yml'))[Rails.env])
