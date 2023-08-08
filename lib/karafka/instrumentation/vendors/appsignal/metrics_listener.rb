# frozen_string_literal: true

require_relative 'base'

module Karafka
  module Instrumentation
    module Vendors
      # Namespace for Appsignal instrumentation
      module Appsignal
        # Listener that ships metrics to Appsignal
        class MetricsListener < Base
          def_delegators :config, :client, :rd_kafka_metrics, :namespace

          # Value object for storing a single rdkafka metric publishing details
          RdKafkaMetric = Struct.new(:type, :scope, :name, :key_location)

          setting :namespace, default: 'karafka'

          setting :client, default: Client.new

          setting :rd_kafka_metrics, default: [
            # Broker metrics
            RdKafkaMetric.new(:count, :brokers, 'requests_retries', 'txretries_d'),
            RdKafkaMetric.new(:count, :brokers, 'transmission_errors', 'txerrs_d'),
            RdKafkaMetric.new(:count, :brokers, 'receive_errors', 'rxerrs_d'),
            RdKafkaMetric.new(:count, :brokers, 'connection_connects', 'connects_d'),
            RdKafkaMetric.new(:count, :brokers, 'connection_disconnects', 'disconnects_d'),
            RdKafkaMetric.new(:gauge, :brokers, 'network_latency_avg', %w[rtt avg]),
            RdKafkaMetric.new(:gauge, :brokers, 'network_latency_p95', %w[rtt p95]),
            RdKafkaMetric.new(:gauge, :brokers, 'network_latency_p99', %w[rtt p99]),

            # Topics metrics
            RdKafkaMetric.new(:gauge, :topics, 'consumer_lags', 'consumer_lag_stored'),
            RdKafkaMetric.new(:gauge, :topics, 'consumer_lags_delta', 'consumer_lag_stored_d')
          ].freeze

          configure

          # Before each consumption process, lets start a transaction associated with it
          # We also set some basic metadata about the given consumption that can be useful for
          # debugging
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_consume(event)
            consumer = event.payload[:caller]

            start_transaction(consumer, 'consume')

            client.metadata = {
              batch_size: consumer.messages.size,
              first_offset: consumer.messages.metadata.first_offset,
              last_offset: consumer.messages.metadata.last_offset,
              consumer_group: consumer.topic.consumer_group.name,
              topic: consumer.topic.name,
              partition: consumer.partition,
              attempt: consumer.coordinator.pause_tracker.attempt
            }
          end

          # Once we're done with consumption, we bump counters about that
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_consumed(event)
            consumer = event.payload[:caller]
            messages = consumer.messages
            metadata = messages.metadata

            count('consumer_messages', messages.size, consumer_tags(consumer))
            count('consumer_batches', 1, consumer_tags(consumer))
            gauge('consumer_offsets', metadata.last_offset, consumer_tags(consumer))

            stop_transaction
          end

          # Keeps track of revocation user code execution
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_revoke(event)
            consumer = event.payload[:caller]
            start_transaction(consumer, 'revoked')
          end

          # Finishes the revocation transaction
          #
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_consumer_revoked(_event)
            stop_transaction
          end

          # Keeps track of revocation user code execution
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_consumer_shutting_down(event)
            consumer = event.payload[:caller]
            start_transaction(consumer, 'shutdown')
          end

          # Finishes the shutdown transaction
          #
          # @param _event [Karafka::Core::Monitoring::Event]
          def on_consumer_shutdown(_event)
            stop_transaction
          end

          # Counts DLQ dispatches
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_dead_letter_queue_dispatched(event)
            consumer = event.payload[:caller]
            count(
              'consumer_dead',
              1,
              consumer_tags(consumer)
            )
          end

          # Reports on **any** error that occurs. This also includes non-user related errors
          # originating from the framework.
          #
          # @param event [Karafka::Core::Monitoring::Event] error event details
          def on_error_occurred(event)
            # If this is a user consumption related error, we bump the counters for metrics
            if event[:type] == 'consumer.consume.error'
              consumer = event.payload[:caller]
              count('consumer_errors', 1, consumer_tags(consumer))
            end

            stop_transaction
          end

          # Hooks up to Karafka instrumentation for emitted statistics
          #
          # @param event [Karafka::Core::Monitoring::Event]
          def on_statistics_emitted(event)
            statistics = event[:statistics]
            consumer_group_id = event[:consumer_group_id]

            rd_kafka_metrics.each do |metric|
              report_metric(metric, statistics, consumer_group_id)
            end
          end

          # Reports a given metric statistics to Appsignal
          # @param metric [RdKafkaMetric] metric value object
          # @param statistics [Hash] hash with all the statistics emitted
          # @param consumer_group_id [String] cg in context which we operate
          def report_metric(metric, statistics, consumer_group_id)
            case metric.scope
            when :root
              # Do nothing on the root metrics as the same metrics are reported in a granular
              # way from other places
              nil
            when :brokers
              statistics.fetch('brokers').each_value do |broker_statistics|
                # Skip bootstrap nodes
                # Bootstrap nodes have nodeid -1, other nodes have positive
                # node ids
                next if broker_statistics['nodeid'] == -1

                public_send(
                  metric.type,
                  metric.name,
                  broker_statistics.dig(*metric.key_location),
                  {
                    broker: broker_statistics['nodename']
                  }
                )
              end
            when :topics
              statistics.fetch('topics').each do |topic_name, topic_values|
                topic_values['partitions'].each do |partition_name, partition_statistics|
                  next if partition_name == '-1'
                  # Skip until lag info is available
                  next if partition_statistics['consumer_lag'] == -1
                  next if partition_statistics['consumer_lag_stored'] == -1

                  public_send(
                    metric.type,
                    metric.name,
                    partition_statistics.dig(*metric.key_location),
                    {
                      consumer_group: consumer_group_id,
                      topic: topic_name,
                      partition: partition_name
                    }
                  )
                end
              end
            else
              raise ArgumentError, metric.scope
            end
          end

          # Increments a counter with a namespace key, value and tags
          #
          # @param key [String] key we want to use (without the namespace)
          # @param value [Integer] count value
          # @param tags [Hash] additional extra tags
          def count(key, value, tags)
            client.count(
              namespaced_metric(key),
              value,
              tags
            )
          end

          # Sets the gauge value
          #
          # @param key [String] key we want to use (without the namespace)
          # @param value [Integer] gauge value
          # @param tags [Hash] additional extra tags
          def gauge(key, value, tags)
            client.gauge(
              namespaced_metric(key),
              value,
              tags
            )
          end

          private

          # Wraps metric name in listener's namespace
          # @param metric_name [String] RdKafkaMetric name
          # @return [String]
          def namespaced_metric(metric_name)
            "#{namespace}_#{metric_name}"
          end

          # Starts the transaction for monitoring user code
          #
          # @param consumer [Karafka::BaseConsumer] karafka consumer instance
          # @param action_name [String] lifecycle user method name
          def start_transaction(consumer, action_name)
            client.start_transaction(
              "#{consumer.class}##{action_name}"
            )
          end

          # Stops the transaction wrapping user code
          def stop_transaction
            client.stop_transaction
          end

          # @param consumer [Karafka::BaseConsumer] Karafka consumer instance
          # @return [Hash] consumer related tags
          def consumer_tags(consumer)
            topic_name = consumer.topic.name
            consumer_group_name = consumer.topic.consumer_group.name
            partition = consumer.partition

            {
              consumer_group: consumer_group_name,
              topic: topic_name,
              partition: partition
            }
          end
        end
      end
    end
  end
end
