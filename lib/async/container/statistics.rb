# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "async/reactor"

module Async
	module Container
		# Tracks various statistics relating to child instances in a container.
		class Statistics
			# Tracks rate information over a sliding time window using a circular buffer.
			class Rate
				# Initialize the event rate counter.
				#
				# @parameter window [Integer] The time window in seconds for rate calculations.
				def initialize(window: 60)
					@window = window
					@samples = [0] * @window
					@last_update = Array.new(@window, 0)
				end
				
				# Get the current time in seconds.
				# @returns [Integer] The current monotonic time in seconds.
				def now
					::Process.clock_gettime(::Process::CLOCK_MONOTONIC).to_i
				end
				
				# Add a value to the current time slot.
				# @parameter value [Numeric] The value to add (default: 1)
				# @parameter time [Integer] The current time in seconds (default: monotonic time)
				def add(value = 1, time: self.now)
					index = time % @samples.size
					
					# If this slot hasn't been updated in a full window cycle, reset it
					if (time - @last_update[index]) >= @window
						@samples[index] = 0
					end
					
					@samples[index] += value
					@last_update[index] = time
				end
				
				# Get the total count in the current window.
				# @parameter time [Integer] The current time in seconds (default: monotonic time)
				# @returns [Numeric] The sum of all samples in the window.
				def total(time: self.now)
					@samples.each_with_index.sum do |value, index|
						# Only count samples that are within the window (inclusive of window boundary)
						if (time - @last_update[index]) <= @window
							value
						else
							0
						end
					end
				end
				
				# Get the rate per second over the window.
				# @parameter time [Integer] The current time in seconds (default: monotonic time)
				# @returns [Float] The average rate per second.
				def per_second(time: self.now)
					total(time: time).to_f / @window
				end
				
				# Get the rate per minute over the window.
				# @parameter time [Integer] The current time in seconds (default: monotonic time)
				# @returns [Float] The average rate per minute.
				def per_minute(time: self.now)
					per_second(time: time) * 60
				end
			end
			# Initialize the statistics all to 0.
			# @parameter window [Integer] The time window in seconds for rate calculations.
			def initialize(window: 60)
				@spawns = 0
				@restarts = 0
				@failures = 0
				
				@restart_rate = Rate.new(window: window)
				@failure_rate = Rate.new(window: window)
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
				@restart_rate.add(1)
			end
			
			# Increment the number of failures by 1.
			def failure!
				@failures += 1
				@failure_rate.add(1)
			end
			
			# Get the restart rate tracker.
			# @attribute [Rate]
			attr :restart_rate
			
			# Get the failure rate tracker.
			# @attribute [Rate]
			attr :failure_rate
			
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
			
			# Generate a hash representation of the statistics.
			#
			# @returns [Hash] The statistics as a hash.
			def as_json(...)
				{
					spawns: @spawns,
					restarts: @restarts,
					failures: @failures,
					restart_rate: @restart_rate.per_second,
					failure_rate: @failure_rate.per_second,
				}
			end
			
			# Generate a JSON representation of the statistics.
			#
			# @returns [String] The statistics as JSON.
			def to_json(...)
				as_json.to_json(...)
			end
		end
	end
end
