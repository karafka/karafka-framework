# frozen_string_literal: true

# Karafka should throttle and wait for the expected time period before continuing the processing

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
      DT[:messages_times] << Time.now.to_f
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    throttling(
      limit: 5,
      interval: 5_000
    )
  end
end

Karafka.monitor.subscribe 'filtering.throttled' do
  DT[:times] << Time.now.to_f
end

elements = DT.uuids(20)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 20
end

# All consumption should work fine, just throttled
assert_equal elements, DT[0]

DT[:times].each_with_index do |slot, index|
  assert_equal(5 * (index + 1), DT[:messages_times].count { |time| time < slot })
end
