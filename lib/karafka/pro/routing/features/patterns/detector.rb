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
          # Detects the new topics available to the routing with the once that are dynamically
          # recognized
          #
          # @note Works only on the primary cluster without option to run on other clusters
          #   If you are seeking this functionality please reach-out.
          #
          # @note This is NOT thread-safe and should run in a thread-safe context that warranties
          #   that there won't be any race conditions
          class Detector
            include ::Karafka::Core::Helpers::Time
            include Singleton

            MUTEX = Mutex.new

            # Looks for new topics matching patterns and if any, will add them to appropriate
            # subscription group and consumer group
            #
            # @note It uses ttl not to request topics with each poll
            def detect(new_topic)
              MUTEX.synchronize do
                ::Karafka::App.consumer_groups.each do |consumer_group|
                  pattern = consumer_group.patterns.find(new_topic)

                  # If there is no pattern we can use, we just move on
                  next unless pattern

                  # If there is a topic, we can use it and add it to the routing
                  install(pattern, new_topic)
                end
              end
            end

            private

            # Adds the discovered topic into the routing
            #
            # @param pattern [Karafka::Pro::Routing::Features::Patterns::Pattern] matched pattern
            # @param discovered_topic [String] topic that we discovered that should be part of the
            #   routing from now on.
            def install(pattern, discovered_topic)
              consumer_group = pattern.topic.consumer_group

              # Build new topic and register within the consumer group
              topic = consumer_group.public_send(:topic=, discovered_topic, &pattern.config)
              topic.patterns(active: true, type: :discovered)

              # Find matching subscription group
              subscription_group = consumer_group.subscription_groups.find do |existing_sg|
                existing_sg.name == topic.subscription_group
              end

              subscription_group || raise(
                ::Karafka::Errors::SubscriptionGroupNotFoundError,
                topic.subscription_group
              )

              # Inject into subscription group topics array always, so everything is reflected
              # there but since it is not active, will not be picked
              subscription_group.topics << topic
            end
          end
        end
      end
    end
  end
end
