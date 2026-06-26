# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require "async"
require "async/clock"

require_relative "error"

module Async
	module Container
		# The default timeout for terminating processes, before escalating to killing.
		GRACEFUL_TIMEOUT = ENV.fetch("ASYNC_CONTAINER_GRACEFUL_TIMEOUT", "true").then do |value|
			case value
			when "true"
				true
			when "false"
				false
			else
				value.to_f
			end
		end
		
		# The default timeout for graceful termination.
		DEFAULT_GRACEFUL_TIMEOUT = 10.0
		
		# Internal child supervision registry.
		#
		# This object intentionally does not model a public collection. It owns the
		# Async task context used for child supervisors and provides just enough
		# coordination for container-level wait, sleep and shutdown operations.
		class Group
			# Initialize the child supervision registry.
			# @parameter health_check_interval [Numeric | Nil] The interval used to wake waiters for periodic health checks.
			def initialize(health_check_interval: 1.0)
				@health_check_interval = health_check_interval
				
				@mutex = Mutex.new
				@children = {}
				@supervisors = 0
				@events = ::Thread::Queue.new
			end
			
			# @attribute [Numeric | Nil] The interval used to wake waiters for periodic health checks.
			attr :health_check_interval
			
			# Generate a human-readable representation of the group.
			# @returns [String] The group inspection string.
			def inspect
				"#<#{self.class} running=#{size}>"
			end
			
			# Get the number of currently registered children.
			# @returns [Integer] The number of running children.
			def size
				@mutex.synchronize{@children.size}
			end
			
			# Check whether any supervisor tasks are still running.
			# @returns [Boolean] Whether any supervisor tasks are running.
			def running?
				@mutex.synchronize{@supervisors.positive?}
			end
			
			# Check whether any supervisor tasks are still running.
			# @returns [Boolean] Whether any supervisor tasks are running.
			def any?
				running?
			end
			
			# Check whether all supervisor tasks have stopped.
			# @returns [Boolean] Whether no supervisor tasks are running.
			def empty?
				!running?
			end
			
			# Compatibility for older tests/code that inspected the implementation.
			# @returns [Hash] A copy of the current child registration map.
			def running
				@mutex.synchronize{@children.dup}
			end
			
			# Run a child supervisor block in the group's Async task context.
			# @yields {...} The supervisor block to execute.
			# @returns [Async::Task] The supervisor task.
			def supervise(&block)
				@mutex.synchronize{@supervisors += 1}
				
				Async::Task.current.async(transient: true) do
					begin
						block.call
					ensure
						@mutex.synchronize{@supervisors -= 1}
						signal!
					end
				end
			end
			
			# Register a child as running.
			# @parameter child [Object] The child to register.
			# @returns [Boolean] The child registration value.
			def insert(child)
				@mutex.synchronize{@children[child] = true}
			end
			
			# Remove a child from the running set and wake waiters.
			# @parameter child [Object] The child to remove.
			# @returns [Object] The queued signal value.
			def delete(child)
				@mutex.synchronize{@children.delete(child)}
				signal!
			end
			
			# Sleep until the group is signalled or the optional duration elapses.
			# @parameter duration [Numeric | Nil] The maximum duration to sleep.
			# @returns [Object | Nil] The queued signal value, or `nil` if the sleep timed out.
			def sleep(duration = nil)
				::Thread.handle_interrupt(SignalException => :immediate) do
					@events.pop(timeout: duration)
				end
			end
			
			# Wait until all supervisor tasks have stopped.
			# @returns [Nil]
			def wait
				sleep while running?
			end
			
			# Wake any waiters so they can re-check child health or state.
			# @returns [Object] The queued signal value.
			def health_check!
				signal!
			end
			
			# Send an interrupt signal to all registered children.
			# @returns [Object] The result of iterating over the current children.
			def interrupt
				Console.info(self, "Sending interrupt to #{size} running children...")
				each_child(&:interrupt!)
			end
			
			# Send a terminate signal to all registered children.
			# @returns [Object] The result of iterating over the current children.
			def terminate
				Console.info(self, "Sending terminate to #{size} running children...")
				each_child(&:terminate!)
			end
			
			# Send a kill signal to all registered children.
			# @returns [Object] The result of iterating over the current children.
			def kill
				Console.info(self, "Sending kill to #{size} running children...")
				each_child(&:kill!)
			end
			
			# Stop all registered children, escalating to kill if graceful shutdown does not complete.
			# @parameter graceful [Boolean | Numeric] Whether to stop gracefully, or the graceful timeout duration.
			# @returns [Nil]
			def stop(graceful = GRACEFUL_TIMEOUT)
				Console.debug(self, "Stopping all children...", graceful: graceful)
				
				if graceful
					interrupt
					
					graceful = DEFAULT_GRACEFUL_TIMEOUT if graceful == true
					wait_for_exit(Clock.start, graceful)
				end
			ensure
				if running?
					if graceful
						Console.warn(self, "Killing children after graceful shutdown failed...", size: size)
					end
					
					kill
					wait
				end
			end
			
			private
			
			def each_child
				children = @mutex.synchronize{@children.keys}
				
				children.each do |child|
					yield child
				rescue Errno::ESRCH
					# The child has already exited.
				end
			end
			
			def wait_for_exit(clock, timeout)
				while running?
					duration = timeout - clock.total
					
					break if duration.negative?
					
					sleep(duration)
				end
			end
			
			def signal!
				@events << true
			end
		end
	end
end
