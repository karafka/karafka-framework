# frozen_string_literal: true

require "active_support/current_attributes"

# This code is based on Mike Perham's approach to persisting current attributes
# on Sidekiq (https://github.com/sidekiq/sidekiq/blob/main/lib/sidekiq/middleware/current_attributes.rb)
module Karafka
  module ActiveJob
    # Module that allows to persist current attributes on Karafka jobs
    module CurrentAttributes
      module Save
        def self.prepended(base)
          base.class_attribute :_cattr_klass
        end

        def serialized_job(job)
          json = super(job)

          if !json.has_key?("cattr")
            attrs = self.class._cattr_klass.constantize.attributes
            json["cattr"] = attrs if attrs.any?
          end

          json
        end
      end

      module Load
        def self.prepended(base)
          base.class_attribute :_cattr_klass
        end

        def with_deserialized_job(job_message, &block)
          super(job_message) do |job|

            if job.has_key?("cattr")
              self.class._cattr_klass.constantize.set(job.delete("cattr")) do
                yield(job)
              end
            else
              yield(job)
            end
          end
        end
      end

      # @param klass [String] class name of the current attributes class
      def self.persist(klass)
        ::Karafka::ActiveJob::Dispatcher.prepend Save
        ::Karafka::ActiveJob::Dispatcher._cattr_klass = klass.to_s

        ::Karafka::ActiveJob::Consumer.prepend Load
        ::Karafka::ActiveJob::Consumer._cattr_klass = klass.to_s
      end
    end
  end
end