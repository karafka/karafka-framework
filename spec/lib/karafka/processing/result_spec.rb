# frozen_string_literal: true

RSpec.describe_current do
  subject(:result) { described_class.new }

  let(:cause) { StandardError.new }

  it { expect(result).to be_success }

  context 'when we succeed' do
    before { result.success! }

    it { expect(result).to be_success }
    it { expect(result.cause).to be(false) }
    it { expect(result.success?).to be(true) }
    it { expect(result.failure?).to be(false) }
  end

  context 'when we fail' do
    before { result.failure!(cause) }

    it { expect(result).not_to be_success }
    it { expect(result.cause).to eq(cause) }
    it { expect(result.success?).to be(false) }
    it { expect(result.failure?).to be(true) }
  end

  context 'when we fail and succeed' do
    before do
      result.failure!(cause)
      result.success!
    end

    it { expect(result).to be_success }
    it { expect(result.cause).to be(false) }
    it { expect(result.success?).to be(true) }
    it { expect(result.failure?).to be(false) }
  end
end
