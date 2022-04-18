# frozen_string_literal: true

# When we have non-critical error happening couple times and we use exponential backoff, Karafka
# should increase the backoff time with each occurrence until max backoff.

setup_karafka do |config|
  config.max_wait_time = 100
  config.max_messages = 1
  config.pause_with_exponential_backoff = true
  config.pause_max_timeout = 5_000
  config.pause_timeout = 200
end


class Consumer < Karafka::BaseConsumer
  def initialize
    DataCollector.data[0] << Time.now.to_f
  end

  def consume
    DataCollector.data[0] << Time.now.to_f

    raise StandardError
  end
end

draw_routes(Consumer)

1.times { |data| produce(DataCollector.topic, '0') }

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 10
end

# Backoff time before next exception occurrence (not before resume). Because of that and the fact
# that we run this in parallel, we add some extra time to compensate.
BACKOFF_RANGES = [
  0..0.5,
  0..1,
  0..1,
  0..1,
  1..2,
  2..3,
  4..5,
  5..7
].freeze

previous = nil

DataCollector.data[0].each_with_index do |timestamp, index|
  unless previous
    previous = timestamp
    next
  end

  backoff = (timestamp - previous)

  assert_equal true, (BACKOFF_RANGES[index] || BACKOFF_RANGES.last).include?(backoff)

  previous = timestamp
end
