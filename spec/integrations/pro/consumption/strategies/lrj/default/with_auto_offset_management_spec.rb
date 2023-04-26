# frozen_string_literal: true

# When using automatic offset management, we should end up with offset committed after the last
# message and we should "be" there upon returning to processing

setup_karafka do |config|
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.last.offset
    # We sleep here so we don't end up consuming so many messages, that the second consumer would
    # hang as there would be no data for him
    sleep(1)
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    topic DT.topic do
      consumer Consumer
      long_running_job true
    end
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[0].size >= 1
end

assert_equal DT[0].last + 1, fetch_first_offset
