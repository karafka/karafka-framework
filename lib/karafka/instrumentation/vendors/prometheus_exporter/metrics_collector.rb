# frozen_string_literal: true

require "prometheus_exporter" # Added for specs
require "prometheus_exporter/server" # Added for specs
require "yaml"
# Note prometheus exporter does not load rails and dependencies
# You must manually require anything you need outside of prometheus_exporter
# This includes Rails helpers like deep_symbolize_keys, present? for a hash, etc
module Karafka
  module Instrumentation
    module Vendors
      module PrometheusExporter
        # The metrics collector is responsible for collecting metrics from the event payload
        # The collector is only run on the prometheus_exporter server and not in the karafka app
        # Once tested ideally it is added directly to the prometheus_exporter repository as a standard collector
        # Once added to prometheus_exporter, Karafka no longer needs to maintain this file
        class MetricsCollector < ::PrometheusExporter::Server::TypeCollector
          # @return [Hash] registry, hash of metric names to their config
          attr_reader :registry, :expireable_metrics, :persistent_metrics, :gauge_names
          MAX_METRIC_AGE = 60
          CONFIG = YAML.load_file(
            File.join(__dir__, "metrics_collector", "config.yaml")
          ).freeze

          def initialize
            @expireable_metrics = ::PrometheusExporter::Server::MetricsContainer.new(ttl: MAX_METRIC_AGE)
            @persistent_metrics = []
            @gauge_names = []
            @registry = {}
          end

          # @param [Hash] hash of metric names to values: {'consumer_lags_delta=' => [2, {label: 1 }] }
          # @return [Hash] the same hash passed in
          def collect(obj)
            ensure_metrics
            collect_metrics(obj)
          end

          # @return [Array<PrometheusExporter::Metric::Base>] Instantiated Prometheus metrics (gauges, counters, etc)
          def metrics
            reset_registry_gauges!
            observe_metrics(expireable_metrics)
            observe_metrics(persistent_metrics)
            persistent_metrics.clear
            registry.values
          end

          # @return [String] karafka, the type of metrics collected
          def type
            "karafka"
          end

          protected

          def reset_registry_gauges!
            gauge_names.each { |name| registry[name]&.reset! }
          end

          def observe_metrics(metric_container)
            metric_container.each do |observed_metric|
              name, payload = observed_metric.values_at("name", "payload")
              metric = registry[name]
              observe_metric(metric, payload)
            end
          end

          def collect_metrics(obj)
            obj["payload"].each do |metric_name, payload|
              name = namespace(metric_name)
              container = gauge_names.include?(name) ? expireable_metrics : persistent_metrics
              container << { "name" => name, "payload" => payload }
            end
          end

          # @param [::PrometheusExporter::Metric::Base] metric
          # @param [Array] payload, tuple or array of tuples [value, {label: 1}] or [[value, {label: 1}], [value, {label: 2}]]
          def observe_metric(metric, payload)
            observe = ->(tuple) { metric.observe(*tuple) }
            return observe[payload] unless payload[0].is_a? Array
            payload.each(&observe)
          end

          # @return [Hash] config, hash of metric names to their config
          def ensure_metrics
            return unless registry.empty?

            CONFIG.each do |metric_name, config|
              type, description, buckets, quantiles = config.values_at("type", "description", "buckets", "quantiles")
              metric_klass = ::PrometheusExporter::Metric.const_get(type)
              name = namespace(metric_name)
              args = [name, description]

              registry[name] = if buckets && type == "Histogram"
                metric_klass.new(*args, buckets: buckets)
              # elsif quantiles && type == "Summary" # Note: Remove? Karafka does not use Summary in DG, Summaries are also not aggregatable so aren't accurate for > 1 karafka server
              #   metric_klass.new(*args, quantiles: quantiles)
              else
                metric_klass.new(*args)
              end

              gauge_names << name if type == "Gauge"
            end
          end

          def namespace(metric_name)
            "karafka_#{metric_name}"
          end
        end
      end
    end
  end
end
