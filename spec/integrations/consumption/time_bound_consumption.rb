# frozen_string_literal: true

# Karafka should be able to consume messages for given amount of time (10 seconds) and then stop
# While Karafka is designed as a long running process, it can be used as recurring job as well

setup_karafka

# How long do we want to process stuff before shutting down Karafka process
MAX_TIME = 10

elements = Array.new(100) { SecureRandom.uuid }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message.raw_payload
    end
  end
end

Karafka::App.routes.draw do
  consumer_group DataCollector.consumer_group do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

# Sends some data so we know all is good
elements.each { |data| produce(DataCollector.topic, data) }

# Stop after 10 seconds
Thread.new do
  sleep(MAX_TIME)
  Karafka::App.stop!
end

time_before = Process.clock_gettime(Process::CLOCK_MONOTONIC)

Karafka::Server.run

time_after = Process.clock_gettime(Process::CLOCK_MONOTONIC)

assert_equal elements, DataCollector.data[0]
assert_equal 1, DataCollector.data.size
# We will give Karafka 2 seconds to stop
assert_equal true, time_after - time_before - MAX_TIME < 2
