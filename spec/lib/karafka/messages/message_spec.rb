# frozen_string_literal: true

RSpec.describe_current do
  let(:base_params_class) { described_class }
  let(:headers) { { message_type: 'test' } }

  describe 'instance methods' do
    subject(:params) { base_params_class.new(raw_payload, metadata) }

    let(:deserializer) { ->(_) { 1 } }
    let(:metadata) do
      ::Karafka::Messages::Metadata.new.tap do |metadata|
        metadata['deserializer'] = deserializer
      end
    end

    describe '#deserialize!' do
      let(:raw_payload) { rand }

      context 'when params are already deserialized' do
        before { params.payload }

        it 'expect not to deserialize again and return self' do
          expect(params).not_to receive(:deserialize)
          expect(params.payload).to eq 1
        end
      end

      context 'when params were not yet deserializeds' do
        let(:raw_payload) { double }
        let(:deserialized_payload) { { double => double } }

        before do
          allow(params)
            .to receive(:deserialize)
            .and_return(deserialized_payload)
        end

        it 'expect to merge with deserialized data that is under payload key' do
          expect(params.payload).to eq deserialized_payload
        end

        it 'expect to mark as deserialized' do
          params.payload
          expect(params.deserialized?).to eq true
        end
      end

      context 'when deserialization error occurs' do
        let(:payload) { double }
        let(:deserialized_payload) { { double => double } }

        before do
          allow(params)
            .to receive(:deserialize)
            .and_raise(Karafka::Errors::BaseError)

          begin
            params.payload
          rescue Karafka::Errors::BaseError
            false
          end
        end

        it 'expect not to mark raw payload as deserialized' do
          expect(params.deserialized?).to eq false
        end
      end
    end

    describe '#deserialize' do
      let(:deserializer) { double }
      let(:raw_payload) { double }

      context 'when we are able to successfully deserialize' do
        let(:deserialized_payload) { { rand => rand } }

        before do
          allow(deserializer)
            .to receive(:call)
            .with(params)
            .and_return(deserialized_payload)
        end

        it 'expect to return payload in a message key' do
          expect(params.send(:deserialize)).to eq deserialized_payload
        end
      end
    end
  end
end
