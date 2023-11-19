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
        class Throttling < Base
          # Namespace for throttling contracts
          module Contracts
            # Rules around throttling settings
            class Topic < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('topic')
              end

              nested(:throttling) do
                required(:active) { |val| [true, false].include?(val) }
                required(:interval) { |val| val.is_a?(Integer) && val.positive? }
                required(:limit) do |val|
                  (val.is_a?(Integer) || val == Float::INFINITY) && val.positive?
                end
              end
            end
          end
        end
      end
    end
  end
end
