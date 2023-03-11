# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Structurable < Base
        # Config for structurable feature
        Config = Struct.new(
          :active,
          :partitions,
          :replication_factor,
          :details,
          keyword_init: true
        ) { alias_method :active?, :active }
      end
    end
  end
end
