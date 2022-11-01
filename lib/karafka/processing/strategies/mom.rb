# frozen_string_literal: true

module Karafka
  module Processing
    module Strategies
      # When using manual offset management, we do not mark as consumed after successful processing
      module Mom
        include Base

        # Apply strategy when only manual offset management is turned on
        FEATURES = %i[
          manual_offset_management
        ].freeze

        # No actions needed for the standard flow here
        def handle_before_enqueue
          nil
        end

        # When manual offset management is on, we do not mark anything as consumed automatically
        # and we rely on the user to figure things out
        def handle_after_consume
          return if revoked?

          if coordinator.success?
            coordinator.pause_tracker.reset
          else
            pause(coordinator.seek_offset)
          end
        end

        # Same as default
        def handle_revoked
          resume

          coordinator.revoke
        end
      end
    end
  end
end
