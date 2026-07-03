# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2026, by Samuel Williams.

require_relative "generic"
require_relative "forked/child"

module Async
	module Container
		# Public factory for multi-process containers.
		module Forked
			def self.new(*arguments, **options)
				Generic.new(Child, *arguments, **options)
			end
			
			def self.multiprocess?
				true
			end
		end
	end
end
