# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running jobs with recoverable errors, we should have the attempts count increased

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 20
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[0] << message.offset }

    DT[:attempts] << coordinator.pause_tracker.attempt
    DT[:raises] << true

    return unless (DT[:raises].count % 2).positive?

    raise(StandardError)
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
    throttling(limit: 10, interval: 1_000)
  end
end

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert DT[:attempts].size >= 2, DT[:attempts]

DT[:attempts].each_slice(2) do |slice|
  # Only interested in full slices
  next unless slice.size == 2

  assert_equal 1, slice[0]
  assert_equal 2, slice[1]
end
