# frozen_string_literal: true

# Karafka should be able to recover from non-critical error when using lrj the same way as any
# normal consumer even if it happens often.
# We should retry from 0 because we do not commit offsets here at all
# We should not change the offset

class Listener
  def on_error_occurred(event)
    DT[:errors] << event
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true)

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError if rand(2).zero?

    messages.each { |message| DT[0] << message.offset }

    sleep 1

    produce_many(DT.topic, DT.uuids(5))
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
      throttling(limit: 15, interval: 5_000)
    end
  end
end

produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[0].size >= 25 && DT[:errors].size >= 5
end

assert DT[0].count(0) > 1

consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

consumer.each do |message|
  assert_equal 0, message.offset, message.offset
  break
end

consumer.close