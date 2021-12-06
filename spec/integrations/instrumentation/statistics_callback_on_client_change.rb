# frozen_string_literal: true

# Karafka should not only recover from critical errors that happened but it also should reload
# the underlying client and keep publishing statistics from the new librdkafka client

ROOT_PATH = Pathname.new(File.expand_path(File.join(File.dirname(__FILE__), '../../../')))
require ROOT_PATH.join('spec/integrations_helper.rb')

setup_karafka

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_groups.first do
    topic DataCollector.topic do
      consumer Class.new
    end
  end
end

stats_events = []

def names(stats_events)
  stats_events
    .map(&:payload)
    .map { |payload| payload[:statistics] }
    .map { |statistics| statistics.fetch('name') }
    .uniq
    .freeze
end

SuperException = Class.new(Exception)

# This will force listener to reload client (hacky, but works)
Karafka::App.monitor.subscribe('connection.listener.fetch_loop.received') do
  raise SuperException
end

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  stats_events << event
end

start_karafka_and_wait_until do
  names(stats_events).size >= 2
end

assert_equal %w[karafka#consumer-1 karafka#consumer-2], names(stats_events)
