# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:combination) do
    %i[
      manual_offset_management
    ]
  end

  it { expect(described_class::FEATURES).to eq(combination) }
end
