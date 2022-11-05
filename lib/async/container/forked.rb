# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.

require_relative 'generic'
require_relative 'process'

module Async
	module Container
		# A multi-process container which uses {Process.fork}.
		class Forked < Generic
			# Indicates that this is a multi-process container.
			def self.multiprocess?
				true
			end
			
			# Start a named child process and execute the provided block in it.
			# @parameter name [String] The name (title) of the child process.
			# @parameter block [Proc] The block to execute in the child process.
			def start(name, &block)
				Process.fork(name: name, &block)
			end
		end
	end
end
