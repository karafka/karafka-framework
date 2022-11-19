# frozen_string_literal: true

# A helper class that we use to run integration specs and collect the results outside of the
# Karafka framework
#
# @note It is a singleton
class DataCollector
  include Singleton

  MUTEX = Mutex.new

  attr_reader :topics, :consumer_groups, :data

  class << self
    # @return [String] topic we want to use in the context of the current spec
    def topic
      instance.topic
    end

    # @return [Array<String>] available topics
    def topics
      instance.topics
    end

    # @return [ConcurrentHash] structure for aggregating data
    def data
      instance.data
    end

    # @return [String] first consumer group
    def consumer_group
      instance.consumer_group
    end

    # @return [Array<String>] available consumer groups
    def consumer_groups
      instance.consumer_groups
    end

    # Alias to the data key (used frequently)
    #
    # @param key [Object] key for the data access
    # @return [Object] anything under given key in the data
    def [](key)
      MUTEX.synchronize do
        data[key]
      end
    end

    # Alias to the data assignment
    #
    # @param key [Object] anything we want to have as a key
    # @param value [Object] anything we want to store
    def []=(key, value)
      MUTEX.synchronize do
        data[key] = value
      end
    end

    # @param amount [Integer] number of uuids we want to get
    # @return [Array<String>] array with uuids
    def uuids(amount)
      Array.new(amount) { SecureRandom.uuid }
    end

    # Removes all the data from the collector
    def clear
      MUTEX.synchronize do
        instance.clear
      end
    end
  end

  # Creates a collector
  def initialize
    @mutex = Mutex.new
    @topics = Concurrent::Array.new(100) { SecureRandom.uuid }
    @consumer_groups = @topics
    @data = Concurrent::Hash.new do |hash, key|
      @mutex.synchronize do
        return hash[key] if hash.key?(key)
        hash[key] = Concurrent::Array.new
      end
    end
  end

  # @return [String] first topic name
  def topic
    topics.first
  end

  # @return [String] first consumer group
  def consumer_group
    topics.first
  end

  # Removes all the data from the collector
  # This may be needed if be buffer rdkafka messages for GC to figure things out
  def clear
    @topics.clear
    @consumer_groups.clear
    @data.clear
  end
end
