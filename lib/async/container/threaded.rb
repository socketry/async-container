# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2026, by Samuel Williams.

require_relative "generic"
require_relative "threaded/child"

module Async
	module Container
		# Public factory for multi-thread containers.
		module Threaded
			def self.new(*arguments, **options)
				Generic.new(Child, *arguments, **options)
			end
			
			def self.multiprocess?
				false
			end
		end
	end
end
