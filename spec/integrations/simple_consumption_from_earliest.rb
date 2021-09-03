# frozen_string_literal: true

setup_karafka

numbers = Array.new(100) { rand.to_s }

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message.raw_payload
    end
  end
end

Karafka::App.consumer_groups.draw do
  consumer_group DataCollector.topic do
    topic DataCollector.topic do
      consumer Consumer
    end
  end
end

Thread.new do
  sleep(0.1) while DataCollector.data[0].size < 100
  Karafka::App.stop!
end

numbers.each do |number|
  Karafka::App.producer.produce_async(
    topic: DataCollector.topic,
    payload: number
  )
end

Karafka::Server.run

assert_equal DataCollector.data[0], numbers
assert_equal DataCollector.data.size, 1
