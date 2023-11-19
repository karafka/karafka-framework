# frozen_string_literal: true

RSpec.describe_current do
  let(:combination) do
    %i[
      filtering
      long_running_job
      virtual_partitions
    ]
  end

  it { expect(described_class::FEATURES).to eq(combination) }
end
