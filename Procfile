web: bundle exec rackup config.ru -p $PORT
worker: bundle exec sidekiq -r ./workers/tomato/next_session_notification_worker.rb -C ./config/sidekiq.yml
