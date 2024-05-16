# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Routing
      module Features
        class Filtering < Base
          # Filtering feature configuration
          Config = Karafka::Routing::BaseConfig.define(:factories) do
            # @return [Boolean] is this feature in use. Are any filters defined
            def active?
              !factories.empty?
            end

            # @return [Array<Object>] array of filters applicable to a topic partition
            def filters
              factories.map(&:call)
            end

            # @return [Hash] this config hash
            def to_h
              super.merge(active: active?)
            end
          end
        end
      end
    end
  end
end
