# frozen_string_literal: true

require 'karafka/pro/base_consumer'
require 'karafka/pro/routing/extensions'

RSpec.describe_current do
  subject(:consumer) do
    topic.singleton_class.include Karafka::Pro::Routing::Extensions

    instance = working_class.new
    instance.pause_tracker = pause_tracker
    instance.topic = topic
    instance
  end

  let(:pause_tracker) { build(:time_trackers_pause) }
  let(:topic) { build(:routing_topic) }
  let(:client) { instance_double(Karafka::Connection::Client, pause: true) }
  let(:first_message) { instance_double(Karafka::Messages::Message, offset: offset, partition: 0) }
  let(:last_message) { instance_double(Karafka::Messages::Message, offset: offset, partition: 0) }
  let(:offset) { 123 }

  let(:messages) do
    instance_double(
      Karafka::Messages::Messages,
      first: first_message,
      last: last_message,
      metadata: instance_double(
        Karafka::Messages::BatchMetadata,
        topic: topic.name,
        partition: 0
      )
    )
  end

  let(:working_class) do
    ClassBuilder.inherit(described_class) do
      attr_reader :consumed

      attr_reader :handled_revoked

      def initialize
        super
        @consumed = false
      end

      def consume
        @consumed = true
      end

      def revoked
        @handled_revoked = true
      end
    end
  end

  describe '#on_consume and #on_after_consume' do
    let(:consume_with_after) do
      lambda do
        consumer.on_consume
        consumer.on_after_consume
      end
    end

    before do
      consumer.pause_tracker = pause_tracker
      consumer.client = client
      consumer.messages = messages
      allow(pause_tracker).to receive(:pause)
    end

    context 'when everything went ok on consume with manual offset management' do
      before { topic.manual_offset_management = true }

      it { expect { consume_with_after.call }.not_to raise_error }

      it 'expect to run proper instrumentation' do
        Karafka.monitor.subscribe('consumer.consumed') do |event|
          expect(event.payload[:caller]).to eq(consumer)
        end

        consume_with_after.call
      end

      it 'expect to never run consumption marking' do
        allow(consumer).to receive(:mark_as_consumed)
        consume_with_after.call
        expect(consumer).not_to have_received(:mark_as_consumed)
      end
    end

    context 'when there was an error on consume with manual offset management' do
      let(:working_class) do
        ClassBuilder.inherit(described_class) do
          attr_reader :consumed

          def initialize
            super
            @consumed = false
          end

          def consume
            raise StandardError
          end
        end
      end

      it { expect { consume_with_after.call }.not_to raise_error }

      it 'expect to pause based on the message offset' do
        consume_with_after.call
        expect(client).to have_received(:pause).with(topic.name, first_message.partition, offset)
      end

      it 'expect to pause with time tracker' do
        consume_with_after.call
        expect(pause_tracker).to have_received(:pause)
      end

      it 'expect to track this with an instrumentation' do
        Karafka.monitor.subscribe('error.occurred') do |event|
          expect(event.payload[:caller]).to eq(consumer)
          expect(event.payload[:error]).to eq(StandardError)
          expect(event.payload[:type]).to eq('consumer.consume.error')
        end
      end
    end

    context 'when everything went ok on consume with automatic offset management' do
      before do
        topic.manual_offset_management = false
        allow(client).to receive(:mark_as_consumed)
      end

      it { expect { consumer.on_consume }.not_to raise_error }

      it 'expect to run proper instrumentation' do
        Karafka.monitor.subscribe('consumer.consumed') do |event|
          expect(event.payload[:caller]).to eq(consumer)
        end

        consumer.on_consume
      end

      it 'expect to never run consumption marking' do
        consume_with_after.call
        expect(client).to have_received(:mark_as_consumed).with(last_message)
      end
    end

    context 'when there was an error on consume with automatic offset management' do
      before { topic.manual_offset_management = false }

      let(:working_class) do
        ClassBuilder.inherit(described_class) do
          attr_reader :consumed

          def initialize
            super
            @consumed = false
          end

          def consume
            raise StandardError
          end
        end
      end

      it { expect { consume_with_after.call }.not_to raise_error }

      it 'expect to pause based on the message offset' do
        consume_with_after.call
        expect(client).to have_received(:pause).with(topic.name, first_message.partition, offset)
      end

      it 'expect to pause with time tracker' do
        consume_with_after.call
        expect(pause_tracker).to have_received(:pause)
      end

      it 'expect to track this with an instrumentation' do
        Karafka.monitor.subscribe('error.occurred') do |event|
          expect(event.payload[:caller]).to eq(consumer)
          expect(event.payload[:error]).to eq(StandardError)
          expect(event.payload[:type]).to eq('consumer.consume.error')
        end
      end
    end
  end

  context 'when revoke happened' do
    it 'expect to run user code' do
      consumer.on_revoked
      expect(consumer.handled_revoked).to eq(true)
      expect(consumer.revoked?).to eq(true)
    end
  end
end
