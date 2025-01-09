# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Routing
      module Features
        class DirectAssignments < Base
          # Direct assignments feature configuration
          Config = Struct.new(:active, :partitions, keyword_init: true) do
            alias_method :active?, :active
          end
        end
      end
    end
  end
end
