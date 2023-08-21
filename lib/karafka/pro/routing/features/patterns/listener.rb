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
          # Listener used to run the periodic new topics detection
          class Listener
            def on_runner_before_call(_)
              Detector.instance.detect
            end

            def on_connection_listener_fetch_loop(_)
              Detector.instance.detect
            end
          end
        end
      end
    end
  end
end