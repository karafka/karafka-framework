# frozen_string_literal: true

# This helper content is being used only in the forked integration tests processes.

ENV['KARAFKA_ENV'] = 'test'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

require 'singleton'
require 'test/unit'
require 'lib/karafka'
require 'spec/support/data_collector'

include Test::Unit::Assertions

# Test setup for the framework
def setup_karafka
  Karafka::App.setup do |config|
    # Use some decent defaults
    config.kafka = { 'bootstrap.servers' => '127.0.0.1:9092' }
    config.client_id = rand.to_s
    config.pause_timeout = 1
    config.pause_max_timeout = 1
    config.pause_with_exponential_backoff = false
    config.max_wait_time = 500

    # Allows to overwrite any option we're interested in
    yield(config) if block_given?
  end

  Karafka.logger.level = 'debug'

  Karafka.monitor.subscribe(Karafka::Instrumentation::StdoutListener.new)
  Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

  Karafka::App.boot!
end
