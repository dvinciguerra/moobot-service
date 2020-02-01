require 'slack-notifier'

module Slack
  class << self
    attr_reader :config

    def configure(options)
      @config = options
    end

    def send_message(message, options: {})
      notifier = ::Slack::Notifier.new(@config[:slack_webhook], channel: @config[:channel], username: @config[:username])
      notifier.ping(message)
    end
  end
end
