# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require 'async/reactor'

module Async
	module Container
		# Tracks various statistics relating to child instances in a container.
		class Statistics
			def initialize
				@spawns = 0
				@restarts = 0
				@failures = 0
			end
			
			# How many child instances have been spawned.
			# @attribute [Integer]
			attr :spawns
			
			# How many child instances have been restarted.
			# @attribute [Integer]
			attr :restarts
			
			# How many child instances have failed.
			# @attribute [Integer]
			attr :failures
			
			# Increment the number of spawns by 1.
			def spawn!
				@spawns += 1
			end
			
			# Increment the number of restarts by 1.
			def restart!
				@restarts += 1
			end
			
			# Increment the number of failures by 1.
			def failure!
				@failures += 1
			end
			
			# Whether there have been any failures.
			# @returns [Boolean] If the failure count is greater than 0.
			def failed?
				@failures > 0
			end
			
			# Append another statistics instance into this one.
			# @parameter other [Statistics] The statistics to append.
			def << other
				@spawns += other.spawns
				@restarts += other.restarts
				@failures += other.failures
			end
		end
	end
end
