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
    module Processing
      module Strategies
        # No features enabled.
        # No manual offset management
        # No long running jobs
        # No virtual partitions
        # Nothing. Just standard, automatic flow
        module Default
          include Base
          include ::Karafka::Processing::Strategies::Default

          # Apply strategy for a non-feature based flow
          FEATURES = %i[].freeze

          # Marks message as consumed in an async way.
          #
          # @param message [Messages::Message] last successfully processed message.
          # @param offset_metadata [String, nil] offset metadata string or nil if nothing
          # @return [Boolean] true if we were able to mark the offset, false otherwise.
          #   False indicates that we were not able and that we have lost the partition.
          #
          # @note We keep track of this offset in case we would mark as consumed and got error when
          #   processing another message. In case like this we do not pause on the message we've
          #   already processed but rather at the next one. This applies to both sync and async
          #   versions of this method.
          def mark_as_consumed(message, offset_metadata = nil)
            if in_transaction?
              mark_in_transaction(message, offset_metadata)
            else
              # seek offset can be nil only in case `#seek` was invoked with offset reset request
              # In case like this we ignore marking
              return true if coordinator.seek_offset.nil?
              # Ignore earlier offsets than the one we already committed
              return true if coordinator.seek_offset > message.offset
              return false if revoked?
              return revoked? unless client.mark_as_consumed(message, offset_metadata)

              coordinator.seek_offset = message.offset + 1
            end

            true
          end

          # Marks message as consumed in a sync way.
          #
          # @param message [Messages::Message] last successfully processed message.
          # @param offset_metadata [String, nil] offset metadata string or nil if nothing
          # @return [Boolean] true if we were able to mark the offset, false otherwise.
          #   False indicates that we were not able and that we have lost the partition.
          def mark_as_consumed!(message, offset_metadata = nil)
            if in_transaction?
              mark_in_transaction(message, offset_metadata)
            else
              # seek offset can be nil only in case `#seek` was invoked with offset reset request
              # In case like this we ignore marking
              return true if coordinator.seek_offset.nil?
              # Ignore earlier offsets than the one we already committed
              return true if coordinator.seek_offset > message.offset
              return false if revoked?

              return revoked? unless client.mark_as_consumed!(message, offset_metadata)

              coordinator.seek_offset = message.offset + 1
            end

            true
          end

          # Starts producer transaction, saves the transaction context for transactional marking
          # and runs user code in this context
          def transaction(&block)
            raise Errors::TransactionAlreadyInitializedError if in_transaction?

            @_transaction_level ||= 0
            error = nil

            begin
              @_transaction_level += 1

              producer.transaction(&block)
            rescue StandardError => e
              error = e
            end

            @_transaction_level -= 1

            if error
              @_transaction_marked = nil

              raise e
            end

            return unless @_transaction_level.zero?
            return unless @_transaction_marked

            # This offset is already stored in transaction but we set it here anyhow because we
            # want to make sure our internal in-memory state is aligned with the transaction
            # @note We never need to use the blocking `#mark_as_consumed!` here because the offset
            #   anyhow was already stored during the transaction
            mark_as_consumed(*@_transaction_marked)

            @_transaction_marked = nil
          end

          # @param message [Messages::Message] message we want to commit inside of a transaction
          # @param offset_metadata [String, nil] offset metadata or nil if none
          def mark_in_transaction(message, offset_metadata)
            raise Errors::TransactionRequiredError unless in_transaction?

            producer.transactional_store_offset(
              client,
              topic.name,
              partition,
              message.offset + 1,
              offset_metadata
            )

            @_transaction_marked = [message, offset_metadata]
          end

          # @return [Boolean] true if invoked inside of a transaction block
          def in_transaction?
            @_transaction_level && @_transaction_level.positive?
          end

          # Allows for cross-virtual-partition consumers locks, transactional locks on LRJ and
          # other cases where we would run any work on same consumer in parallel
          #
          # This is not needed in the non-VP flows except LRJ because there is always only one
          # consumer per partition at the same time, so no coordination is needed directly for
          # the end users. With LRJ it is needed and provided in the `LRJ::Default` strategy,
          # because lifecycle events on revocation can run in parallel to the LRJ job as it is
          # non-blocking.
          #
          # 
          #
          # @param block [Proc] block we want to run in a mutex to prevent race-conditions
          def synchronize(&block)
            coordinator.shared_mutex.synchronize(&block)
          end

          # No actions needed for the standard flow here
          def handle_before_schedule_consume
            Karafka.monitor.instrument('consumer.before_schedule_consume', caller: self)

            nil
          end

          # Increment number of attempts per one "full" job. For all VP on a single topic partition
          # this also should run once.
          def handle_before_consume
            coordinator.on_started do
              coordinator.pause_tracker.increment
            end
          end

          # Run the user consumption code
          def handle_consume
            # We should not run the work at all on a partition that was revoked
            # This can happen primarily when an LRJ job gets to the internal worker queue and
            # this partition is revoked prior processing.
            unless revoked?
              Karafka.monitor.instrument('consumer.consume', caller: self)
              Karafka.monitor.instrument('consumer.consumed', caller: self) do
                consume
              end
            end

            # Mark job as successful
            coordinator.success!(self)
          rescue StandardError => e
            # If failed, mark as failed
            coordinator.failure!(self, e)

            # Re-raise so reported in the consumer
            raise e
          ensure
            # We need to decrease number of jobs that this coordinator coordinates as it has
            # finished
            coordinator.decrement
          end

          # Standard flow without any features
          def handle_after_consume
            coordinator.on_finished do |last_group_message|
              return if revoked?

              if coordinator.success?
                coordinator.pause_tracker.reset

                # Do not mark last message if pause happened. This prevents a scenario where pause
                # is overridden upon rebalance by marking
                return if coordinator.manual_pause?

                mark_as_consumed(last_group_message)
              else
                retry_after_pause
              end
            end
          end

          # Standard flow for revocation
          def handle_revoked
            coordinator.on_revoked do
              resume

              coordinator.revoke
            end

            Karafka.monitor.instrument('consumer.revoke', caller: self)
            Karafka.monitor.instrument('consumer.revoked', caller: self) do
              revoked
            end
          end

          # No action needed for the tick standard flow
          def handle_before_schedule_tick
            Karafka.monitor.instrument('consumer.before_schedule_tick', caller: self)

            nil
          end

          # Runs the consumer `#tick` method with reporting
          def handle_tick
            Karafka.monitor.instrument('consumer.tick', caller: self)
            Karafka.monitor.instrument('consumer.ticked', caller: self) do
              tick
            end
          end
        end
      end
    end
  end
end
