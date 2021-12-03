# frozen_string_literal: true

# Karafka should publish async errors from the client via a dedicated instrumentation hook

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

statistics_events = []

Karafka::App.monitor.subscribe('statistics.emitted') do |event|
  statistics_events << event
end

start_karafka_and_wait_until do
  !statistics_events.empty?
end

event = statistics_events.first

assert_not_equal 0, statistics_events.size
assert_equal true, event.is_a?(Dry::Events::Event)
assert_equal 'statistics.emitted', event.id
assert_not_equal '', event.payload[:subscription_group_id]
assert_equal true, event.payload[:consumer_group_id].include?(DataCollector.consumer_groups.first)
assert_equal true, event.payload[:statistics].is_a?(Hash)
assert_equal 0, event.payload[:statistics]['txmsgs_d']
assert_equal true, event.payload[:statistics]['name'].include?('karafka')
