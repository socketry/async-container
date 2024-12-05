# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.

require_relative "generic"
require_relative "thread"

module Async
	module Container
		# A multi-thread container which uses {Thread.fork}.
		class Threaded < Generic
			# Indicates that this is not a multi-process container.
			def self.multiprocess?
				false
			end
			
			# Start a named child thread and execute the provided block in it.
			# @parameter name [String] The name (title) of the child process.
			# @parameter block [Proc] The block to execute in the child process.
			def start(name, &block)
				Thread.fork(name: name, &block)
			end
		end
	end
end
