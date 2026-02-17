# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require "fiber"
require "async/clock"

require_relative "error"

module Async
	module Container
		# The default timeout for terminating processes, before escalating to killing.
		GRACEFUL_TIMEOUT = ENV.fetch("ASYNC_CONTAINER_GRACEFUL_TIMEOUT", "true").then do |value|
			case value
			when "true"
				true # Default timeout for graceful termination.
			when "false"
				false # Immediately kill the processes.
			else
				value.to_f
			end
		end
		
		# The default timeout for graceful termination.
		DEFAULT_GRACEFUL_TIMEOUT = 10.0
		
		# Manages a group of running processes.
		class Group
			# Initialize an empty group.
			#
			# @parameter health_check_interval [Numeric | Nil] The (biggest) interval at which health checks are performed.
			def initialize(health_check_interval: 1.0)
				@health_check_interval = health_check_interval
				
				# The running fibers, indexed by IO:
				@running = {}
			end
			
			# @returns [String] A human-readable representation of the group.
			def inspect
				"#<#{self.class} running=#{@running.size}>"
			end
			
			# @attribute [Hash(IO, Fiber)] the running tasks, indexed by IO.
			attr :running
			
			# @returns [Integer] The number of running processes.
			def size
				@running.size
			end
			
			# Whether the group contains any running processes.
			# @returns [Boolean]
			def running?
				@running.any?
			end
			
			# Whether the group contains any running processes.
			# @returns [Boolean]
			def any?
				@running.any?
			end
			
			# Whether the group is empty.
			# @returns [Boolean]
			def empty?
				@running.empty?
			end
			
			# Sleep for at most the specified duration until some state change occurs.
			def sleep(duration)
				self.wait_for_children(duration)
			end
			
			# Begin any outstanding queued processes and wait for them indefinitely.
			def wait
				with_health_checks do |duration|
					self.wait_for_children(duration)
				end
			end
			
			private def with_health_checks
				if @health_check_interval
					health_check_clock = Clock.start
					
					while self.running?
						duration = [@health_check_interval - health_check_clock.total, 0].max
						
						yield duration
						
						if health_check_clock.total > @health_check_interval
							self.health_check!
							health_check_clock.reset!
						end
					end
				else
					while self.running?
						yield nil
					end
				end
			end
			
			private def each_running(&block)
				# We create a copy of the values here, in case the block modifies the running set:
				@running.values.each(&block)
			end
			
			# Perform a health check on all running processes.
			def health_check!
				each_running do |fiber|
					fiber.resume(:health_check!)
				end
			end
			
			# Interrupt all running processes.
			# This resumes the controlling fiber with an instance of {Interrupt}.
			def interrupt
				Console.info(self, "Sending interrupt to #{@running.size} running processes...")
				each_running do |fiber|
					fiber.resume(Interrupt)
				end
			end
			
			# Terminate all running processes.
			# This resumes the controlling fiber with an instance of {Terminate}.
			def terminate
				Console.info(self, "Sending terminate to #{@running.size} running processes...")
				each_running do |fiber|
					fiber.resume(Terminate)
				end
			end
			
			# Kill all running processes.
			# This resumes the controlling fiber with an instance of {Kill}.
			def kill
				Console.info(self, "Sending kill to #{@running.size} running processes...")
				each_running do |fiber|
					fiber.resume(Kill)
				end
			end
			
			private def wait_for_exit(clock, timeout)
				while self.any?
					duration = timeout - clock.total
					
					if duration >= 0
						self.wait_for_children(duration)
					else
						self.wait_for_children(0)
						break
					end
				end
			end
			
			# Stop all child processes with a multi-phase shutdown sequence.
			#
			# A graceful shutdown performs the following sequence:
			# 1. Send SIGINT and wait up to `graceful` seconds if specified.
			# 2. Send SIGKILL and wait indefinitely for process cleanup.
			#
			# If `graceful` is true, default to `DEFAULT_GRACEFUL_TIMEOUT` (10 seconds).
			# If `graceful` is false, skip the SIGINT phase and go directly to SIGKILL.
			#
			# @parameter graceful [Boolean | Numeric] Whether to send SIGINT first or skip directly to SIGKILL.
			def stop(graceful = GRACEFUL_TIMEOUT)
				Console.debug(self, "Stopping all processes...", graceful: graceful)
				
				# If a timeout is specified, interrupt the children first:
				if graceful
					# Send SIGINT to the children:
					self.interrupt
					
					if graceful == true
						graceful = DEFAULT_GRACEFUL_TIMEOUT
					end
					
					clock = Clock.start
					
					# Wait for the children to exit:
					self.wait_for_exit(clock, graceful)
				end
			ensure
				# Do our best to clean up the children:
				if any?
					if graceful
						Console.warn(self, "Killing processes after graceful shutdown failed...", size: self.size, clock: clock)
					end
					
					self.kill
					self.wait
				end
			end
			
			# Wait for a message in the specified {Channel}.
			def wait_for(channel)
				io = channel.in
				
				@running[io] = Fiber.current
				
				while @running.key?(io)
					# Wait for some event on the channel:
					result = Fiber.yield
					
					if result == Interrupt
						channel.interrupt!
					elsif result == Terminate
						channel.terminate!
					elsif result == Kill
						channel.kill!
					elsif result
						yield result
					elsif message = channel.receive
						yield message
					else
						# Wait for the channel to exit:
						return channel.wait
					end
				end
			ensure
				@running.delete(io)
			end
			
			protected
			
			def wait_for_children(duration = nil)
				# This log is a bit noisy and doesn't really provide a lot of useful information:
				Console.debug(self, "Waiting for children...", duration: duration, running: @running)
				
				unless @running.empty?
					# Maybe consider using a proper event loop here:
					if ready = self.select(duration)
						ready.each do |io|
							if fiber = @running[io]
								# This method can be re-entered. While resuming a fiber, a policy hook may be invoked, which may invoke operations on the container. In that case, select may be called again on the same set of waiting fibers. On returning, those fibers may have already completed and removed themselves from @running, so we need to check for that.
								fiber.resume
							end
						end
					end
				end
			end
			
			# Wait for a child process to exit OR a signal to be received.
			def select(duration)
				::Thread.handle_interrupt(SignalException => :immediate) do
					readable, _, _ = ::IO.select(@running.keys, nil, nil, duration)
					
					return readable
				end
			end
		end
	end
end
