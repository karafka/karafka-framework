# frozen_string_literal: true

# Karafka should trigger an on_revoked action when a partition is being taken from us

setup_karafka

DataCollector[:revoked] = Concurrent::Array.new
DataCollector[:pre] = Set.new
DataCollector[:post] = Set.new

class Consumer < Karafka::BaseConsumer
  def consume
    if DataCollector[:revoked].empty?
      DataCollector[:pre] << messages.metadata.partition
    else
      DataCollector[:post] << messages.metadata.partition
    end
  end

  def revoked
    # We are interested only in the first rebalance
    return unless DataCollector[:done].empty?

    DataCollector[:done] << true

    DataCollector[:revoked] << { messages.metadata.partition => Time.now }
  end
end

draw_routes do
  consumer_group 'integrations_1_03' do
    topic 'integrations_1_03' do
      consumer Consumer
      manual_offset_management true
    end
  end
end

elements = Array.new(100) { SecureRandom.uuid }
elements.each { |data| produce('integrations_1_03', data, partition: rand(0..2)) }

config = {
  'bootstrap.servers': 'localhost:9092',
  'group.id': Karafka::App.consumer_groups.first.id,
  'auto.offset.reset': 'earliest'
}
consumer = Rdkafka::Config.new(config).consumer

other =  Thread.new do
  sleep(10)

  consumer.subscribe('integrations_1_03')
  # 1 message is enough
  consumer.each do
    consumer.close
    break
  end
end

start_karafka_and_wait_until do
  !DataCollector[:post].empty?
end

other.join
consumer.close

# Rebalance should not revoke all the partitions
assert DataCollector[:revoked].size < 3
assert (DataCollector[:revoked].flat_map(&:keys) - [0, 1, 2]).empty?
# Before revocation, we should have had all the partitions in our first process
assert_equal [0, 1, 2], DataCollector[:pre].to_a.sort

re_assigned = DataCollector[:post].to_a.sort
# After rebalance we should not get all partitions back as now there are two consumers
assert_not_equal [0, 1, 2], re_assigned
# It may get either one or two partitions back
assert re_assigned.size == 1 || re_assigned.size == 2
