# frozen_string_literal: true

# Manual seek per user request should super-seed the automatic LRJ movement.
# Filter that would require seek, should use the user requested offset over its own

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:'max.poll.interval.ms'] = 10_000
  config.kafka[:'session.timeout.ms'] = 10_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[0] << messages.first.offset

    seek(0)
  end
end

class Filter
  def apply!(messages)
    @applied = true

    messages
  end

  def action
    :seek
  end

  def applied?
    true
  end

  def timeout
    0
  end

  def cursor
    raise
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    long_running_job true
    manual_offset_management true
    filter(->(*) { Filter.new })
  end
end

produce_many(DT.topics[0], DT.uuids(10))

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert_equal [0], DT[0].uniq
