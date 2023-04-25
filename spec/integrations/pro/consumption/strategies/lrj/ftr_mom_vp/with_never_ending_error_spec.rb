# frozen_string_literal: true

# When doing work with error, we should slowly increase the attempt count for LRJ same as for
# regular workloads, despite pausing.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attempts] << coordinator.pause_tracker.attempt

    raise StandardError
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
      throttling(limit: 1_000_000, interval: 100_000)
      virtual_partitions(
        partitioner: ->(_msg) { rand(9) }
      )
    end
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:attempts].size >= 20
end

assert_equal [], (1..20).to_a - DT[:attempts], DT[:attempts]

consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

consumer.each do |message|
  assert_equal 0, message.offset
  break
end

consumer.close