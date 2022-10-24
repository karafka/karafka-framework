# frozen_string_literal: true

# This Karafka component is a Pro component.
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
        class ProInheritance < Karafka::Routing::Features::Base
          # Rules around manual offset management settings
          class Contract < Contracts::Base
            # Contract for validating correct Pro components setup on a topic levels
            configure do |config|
              config.error_messages = YAML.safe_load(
                File.read(
                  File.join(Karafka.gem_root, 'config', 'errors.yml')
                )
              ).fetch('en').fetch('validations').fetch('pro_topic')
            end

            virtual do |data, errors|
              next unless errors.empty?
              next if data[:consumer] < Karafka::Pro::BaseConsumer

              [[%i[consumer], :consumer_format]]
            end
          end
        end
      end
    end
  end
end
