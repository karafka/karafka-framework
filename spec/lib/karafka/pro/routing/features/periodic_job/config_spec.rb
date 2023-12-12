# frozen_string_literal: true

RSpec.describe_current do
  subject(:config) { described_class.new(active: active, frequency: frequency) }

  let(:active) { true }
  let(:frequency) { 1_000 }

  describe '#active?' do
    context 'when active' do
      it { expect(config.active?).to eq(true) }
    end

    context 'when not active' do
      let(:active) { false }

      it { expect(config.active?).to eq(false) }
    end
  end
end
