# frozen_string_literal: true

# Karafka+Pro should work with Rails 7 using the default setup

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'rails', '7.0.2.2'
  gem 'karafka', path: gemified_karafka_root
end

require 'rails'
require 'karafka'

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

Rails.configuration.middleware.delete ActionDispatch::Static

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

ExampleApp.initialize!

setup_karafka do |config|
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    DataCollector.data[0] << true
  end
end

draw_routes(Consumer)
produce(DataCollector.topic, '1')

start_karafka_and_wait_until do
  DataCollector.data[0].size >= 1
end

assert_equal 1, DataCollector.data.size
assert_equal '7.0.2.2', Rails.version
