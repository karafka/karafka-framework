# frozen_string_literal: true

module Karafka
  # FIFO scheduler for messages coming from various topics and partitions
  class Scheduler
    # Yields jobs in the fifo order
    #
    # @param [Array<Karafka::Processing::Jobs::Base>] jobs we want to schedule
    # @yieldparam [Karafka::Processing::Jobs::Base] job we want to enqueue
    def call(jobs_array)
      jobs_array.each do |job|
        yield job
      end
    end
  end
end
