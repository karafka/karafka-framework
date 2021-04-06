# frozen_string_literal: true

RSpec.describe_current do
  subject(:messages) do
    Karafka::Messages::Builders::Messages.call(kafka_messages, topic, received_at)
  end

  let(:deserialized_payload) { { rand.to_s => rand.to_s } }
  let(:serialized_payload) { deserialized_payload.to_json }
  let(:topic) { build(:routing_topic) }
  let(:kafka_message1) { build(:kafka_fetched_message, payload: serialized_payload) }
  let(:kafka_message2) { build(:kafka_fetched_message, payload: serialized_payload) }
  let(:kafka_messages) { [kafka_message1, kafka_message2] }
  let(:received_at) { Time.now }

  describe '#to_a' do
    it 'expect not to deserialize data and return raw messages' do
      expect(messages.to_a.first.deserialized?).to eq false
    end
  end

  describe '#deserialize!' do
    it 'expect to deserialize all the messages and return deserialized' do
      messages.deserialize!
      messages.to_a.each { |params| expect(params.deserialized?).to eq true }
    end
  end

  describe '#each' do
    it 'expect not to deserialize each at a time' do
      messages.each_with_index do |params, index|
        expect(params.deserialized?).to eq false
        next if index > 0

        expect(messages.to_a[index + 1].deserialized?).to eq false
      end
    end
  end

  describe '#payloads' do
    it 'expect to return deserialized payloads from params within params batch' do
      expect(messages.payloads).to eq [deserialized_payload, deserialized_payload]
    end

    context 'when payloads were used for the first time' do
      before { messages.payloads }

      it 'expect to mark as serialized all the params inside the batch' do
        expect(messages.to_a.all?(&:deserialized?)).to eq true
      end
    end
  end

  describe '#first' do
    it 'expect to return first element without deserializing' do
      expect(messages.first).to eq messages.to_a[0]
      expect(messages.first.deserialized?).to eq false
    end
  end

  describe '#last' do
    it 'expect to return last element without deserializing' do
      expect(messages.last).to eq messages.to_a[-1]
      expect(messages.last.deserialized?).to eq false
    end
  end

  describe '#size' do
    it { expect(messages.size).to eq messages.to_a.size }
  end
end
