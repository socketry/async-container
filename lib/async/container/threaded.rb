# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2026, by Samuel Williams.

require_relative "generic"
require_relative "threaded/child"

module Async
	module Container
		# Public factory for multi-thread containers.
		module Threaded
			# Create a generic container which spawns threaded children.
			# @parameter arguments [Array] Positional arguments for {Generic#initialize}.
			# @parameter options [Hash] Keyword options for {Generic#initialize}.
			# @returns [Generic] A generic container configured with {Threaded::Child}.
			def self.new(*arguments, **options)
				Generic.new(Child, *arguments, **options)
			end
			
			# Whether this container uses multiple processes.
			# @returns [Boolean]
			def self.multiprocess?
				false
			end
		end
	end
end
