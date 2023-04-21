# frozen_string_literal: true

# When running jobs without problems, there should always be only one attempt even if throttling
# occurs

setup_karafka do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attempts] << coordinator.pause_tracker.attempt

    messages.each { |message| DT[0] << message.offset }
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
      manual_offset_management true
      throttling(limit: 5, interval: 2_000)
      virtual_partitions(
        partitioner: ->(_msg) { rand(9) }
      )
    end
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

DT[:attempts].each { |attempt| assert_equal 1, attempt, DT[:attempts] }

consumer = setup_rdkafka_consumer
consumer.subscribe(DT.topic)

consumer.each do |message|
  assert_equal 0, message.offset
  break
end

consumer.close
