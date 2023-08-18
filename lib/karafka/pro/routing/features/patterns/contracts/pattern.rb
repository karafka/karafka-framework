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
        class Patterns < Base
          # Namespace for patterns related contracts
          module Contracts
            # Contract used to validate pattern data
            class Pattern < Karafka::Contracts::Base
              configure do |config|
                config.error_messages = YAML.safe_load(
                  File.read(
                    File.join(Karafka.gem_root, 'config', 'locales', 'pro_errors.yml')
                  )
                ).fetch('en').fetch('validations').fetch('pattern')

                required(:regexp) { |val| val.is_a?(Regexp) }

                required(:topic_name) do |val|
                  val.is_a?(String) && Karafka::Contracts::TOPIC_REGEXP.match?(val)
                end
              end
            end
          end
        end
      end
    end
  end
end