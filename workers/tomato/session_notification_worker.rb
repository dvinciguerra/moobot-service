require 'http'
require 'sidekiq'
require_relative '../../lib/slack'

Sidekiq.configure_server do |config|
  config.redis = { url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}" }
  config.average_scheduled_poll_interval = 15
end

module Tomato
  class SessionNotificatonWorker
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(tomato_session)
      id, channel, current_user, users = tomato_session.values_at('id', 'channel', 'current_user', 'users')

      ::Slack.configure(
        slack_webhook: ENV['SLACK_URL'],
        channel: channel,
        username: ENV['BOT_NAME']
      )

      Sidekiq.logger.info(tomato_session.inspect);
      ::Slack.send_message(
        "[session:#{id}]  #{current_user}, pomodoro time!!! Starting next user session (#{users.rotate.first})"
      )

      HTTP.put("#{ENV['API_HOST']}/tomato/#{id}/next")
    end
  end
end
