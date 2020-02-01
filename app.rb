# frozen_string_literal: true

require 'rubygems'
require 'sidekiq/api'
require 'sinatra'
require 'sinatra/json'
require 'securerandom'

require_relative './lib/slack'
require_relative './workers/tomato/session_notification_worker'

use Rack::Logger

@@store = []

set :root, File.dirname(__FILE__)
set :logger, Logger.new(STDOUT)

mime_type :json, 'application/json'

before do
  content_type :json
end

helpers do
  def payload
    request.body.rewind
    @@payload =
      begin
        JSON.parse(request.body.read, symbolize_names: true)
      rescue StandardError
        {}
      end
  end

  def json(dataset)
    return no_data! unless dataset

    dataset.to_json
  end

  def no_data!
    status 204
    json message: 'no data'
  end

  def slack_notification(message, options = {})
    channel = options.values_at(:channel)

    ::Slack.configure(
      slack_webhook: ENV["SLACK_URL"],
      channel: channel,
      username: 'moobot'
    )

    ::Slack.send_message(message)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV['REDIS_HOST']}:#{ENV['REDIS_PORT']}" }
end

def delete_job(job_id)
  queue = Sidekiq::ScheduledSet.new
  queue.each { |job| job.delete if job.jid == job_id }
end

def session_notification_at(starts_at, tomato_session)
  Tomato::SessionNotificatonWorker.perform_at(starts_at, tomato_session)
end

get '/tomato/sessions' do
  logger.info(p(@@store))
  json(@@store)
end

post '/tomato/start' do
  time_now = Time.now.utc
  minutes = payload[:minutes] || 25
  finish_at = Time.at(time_now + (minutes.to_i * 60))

  new_session = {
    id: SecureRandom.uuid,
    minutes: minutes.to_i,
    users: payload[:users] || [],
    current_user: payload[:users].first,
    created_at: time_now,
    finish_at: finish_at,
    channel: payload[:channel] || 'default',
  }

  job_id = session_notification_at(finish_at, new_session)

  @@store << new_session.merge!(job_id: job_id)

  logger.info(p(new_session.inspect))
  json(new_session)
end

put '/tomato/:id/next' do
  session_id = params[:id]
  current_session = @@store.find { |session| session[:id] == session_id }

  time_now = Time.now.utc
  minutes = payload[:minutes] || current_session[:minutes]
  finish_at = Time.at(time_now + (minutes.to_i * 60))
  users = current_session[:users].rotate

  delete_job(current_session[:job_id])

  next_session = current_session.merge(
    users: users,
    current_user: users.first,
    minutes: minutes,
    created_at: time_now,
    finish_at: Time.at(time_now + (minutes.to_i * 60))
  )

  job_id = session_notification_at(finish_at, next_session)

  @@store
    .reject! { |session| session[:id] == session_id }
    .push(next_session.merge!(job_id: job_id))

  logger.info(p(next_session.inspect))
  json(next_session)
end

put '/tomato/:id/stop' do
  session_id = params[:id]
  current_session = @@store.find { |session| session[:id] == session_id }

  delete_job(current_session[:job_id])

  @@store.reject! { |session| session[:id] == session_id }

  json({ message: 'tomato session stopped' })
end

put '/tomato/:id/restart' do
  session_id = params[:id]
  current_session = @@store.find { |session| session[:id] == session_id }

  time_now = Time.now.utc
  minutes = payload[:minutes] || current_session[:minutes]
  finish_at = Time.at(time_now + (minutes.to_i * 60))

  delete_job(current_session[:job_id])

  new_session = current_session.merge(
    minutes: minutes,
    created_at: time_now,
    finish_at: Time.at(time_now + (minutes.to_i * 60)),
  )

  job_id = session_notification_at(finish_at, new_session)

  @@store
    .reject! { |session| session[:id] == session_id }
    .push(new_session.merge!(job_id: job_id))

  logger.info(p(new_session.inspect))
  json(new_session)
end
