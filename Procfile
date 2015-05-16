web: bundle exec rails server -p $PORT
worker:  bundle exec rake jobs:work
resque: env TERM_CHILD=1 RESQUE_TERM_TIMEOUT=7 bundle exec rake resque:work