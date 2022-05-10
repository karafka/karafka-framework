# frozen_string_literal: true

# Karafka should be able to easily consume all the messages from earliest (default)

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DataCollector.data[message.metadata.partition] << message.raw_payload
    end
  end
end

draw_routes(Consumer)

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce(DataCollector.topic, data) }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 100
end

assert_equal elements, DataCollector.data[0]
assert_equal 1, DataCollector.data.size
