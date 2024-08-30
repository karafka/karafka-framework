# frozen_string_literal: true

# When there are future dispatches, they should not be dispatched unless the time is right
# Stats should be populated nicely though.
# One message (newest in the topic) should be dispatched though

setup_karafka

draw_routes do
  scheduled_messages(topics_namespace: DT.topic)

  topic DT.topic do
    active(false)
  end
end

distant_future = Array.new(50) do |i|
  message = {
    topic: DT.topic,
    key: "key#{i}",
    headers: { 'b' => i.to_s },
    payload: "payload#{i}"
  }

  Karafka::Pro::ScheduledMessages.proxy(
    message: message,
    epoch: Time.now.to_i + 60 + (3_600 * i),
    envelope: { topic: "#{DT.topic}messages" }
  )
end

close_future = Array.new(2) do |i|
  message = {
    topic: DT.topic,
    key: "key#{i + 100}",
    headers: { 'b' => (i + 100).to_s },
    payload: "payload#{i + 100}"
  }

  Karafka::Pro::ScheduledMessages.proxy(
    message: message,
    epoch: Time.now.to_i + 1,
    envelope: { topic: "#{DT.topic}messages" }
  )
end

Karafka.producer.produce_many_sync(distant_future)
Karafka.producer.produce_many_sync(close_future)

dispatched = nil
state = nil

start_karafka_and_wait_until do
  dispatched = Karafka::Admin.read_topic(DT.topic, 0, 100)
  state = Karafka::Admin.read_topic("#{DT.topic}states", 0, 1).first

  if dispatched.size < 2 || state.nil?
    sleep(1)
    next false
  end

  next false unless state.payload[:daily].size >= 2

  true
end

tomorrow_date = Date.today + 1
tomorrow_date_str = tomorrow_date.strftime('%Y-%m-%d')

# This spec is time based, so we cannot check all direct references
assert state.payload[:daily].key?(tomorrow_date_str.to_sym)

assert_equal 2, dispatched.size

assert_equal dispatched.map(&:key).sort, %w[key100 key101]
