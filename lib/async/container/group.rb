# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require "fiber"
require "async/clock"

require_relative "error"

module Async
	module Container
		# The default timeout for interrupting processes, before escalating to terminating.
		INTERRUPT_TIMEOUT = ENV.fetch("ASYNC_CONTAINER_INTERRUPT_TIMEOUT", 10).to_f
		
		# The default timeout for terminating processes, before escalating to killing.
		TERMINATE_TIMEOUT = ENV.fetch("ASYNC_CONTAINER_TERMINATE_TIMEOUT", 10).to_f
		
		# Manages a group of running processes.
		class Group
			# Initialize an empty group.
			#
			# @parameter health_check_interval [Numeric | Nil] The (biggest) interval at which health checks are performed.
			def initialize(health_check_interval: 1.0)
				@health_check_interval = health_check_interval
				
				# The running fibers, indexed by IO:
				@running = {}
				
				# This queue allows us to wait for processes to complete, without spawning new processes as a result.
				@queue = nil
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
				self.resume
				self.suspend
				
				self.wait_for_children(duration)
			end
			
			# Begin any outstanding queued processes and wait for them indefinitely.
			def wait
				self.resume
				
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
			
			# Perform a health check on all running processes.
			def health_check!
				@running.each_value do |fiber|
					fiber.resume(:health_check!)
				end
			end
			
			# Interrupt all running processes.
			# This resumes the controlling fiber with an instance of {Interrupt}.
			def interrupt
				Console.info(self, "Sending interrupt to #{@running.size} running processes...")
				@running.each_value do |fiber|
					fiber.resume(Interrupt)
				end
			end
			
			# Terminate all running processes.
			# This resumes the controlling fiber with an instance of {Terminate}.
			def terminate
				Console.info(self, "Sending terminate to #{@running.size} running processes...")
				@running.each_value do |fiber|
					fiber.resume(Terminate)
				end
			end
			
			# Kill all running processes.
			# This resumes the controlling fiber with an instance of {Kill}.
			def kill
				Console.info(self, "Sending kill to #{@running.size} running processes...")
				@running.each_value do |fiber|
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
			# 1. Send SIGINT and wait up to `interrupt_timeout` seconds
			# 2. Send SIGTERM and wait up to `terminate_timeout` seconds  
			# 3. Send SIGKILL and wait indefinitely for process cleanup
			#
			# If `graceful` is false, skips the SIGINT phase and goes directly to SIGTERM → SIGKILL.
			#
			# @parameter graceful [Boolean] Whether to send SIGINT first or skip directly to SIGTERM.
			# @parameter interrupt_timeout [Numeric | Nil] Time to wait after SIGINT before escalating to SIGTERM.
			# @parameter terminate_timeout [Numeric | Nil] Time to wait after SIGTERM before escalating to SIGKILL.
			def stop(graceful = true, interrupt_timeout: INTERRUPT_TIMEOUT, terminate_timeout: TERMINATE_TIMEOUT)
				case graceful
				when true
					# Use defaults.
				when false
					interrupt_timeout = nil
				when Numeric
					interrupt_timeout = graceful
					terminate_timeout = graceful
				end
				
				Console.debug(self, "Stopping all processes...", interrupt_timeout: interrupt_timeout, terminate_timeout: terminate_timeout)
				
				# If a timeout is specified, interrupt the children first:
				if interrupt_timeout
					clock = Async::Clock.start
					
					# Interrupt the children:
					self.interrupt
					
					# Wait for the children to exit:
					self.wait_for_exit(clock, interrupt_timeout)
				end
				
				if terminate_timeout and self.any?
					clock = Async::Clock.start
					
					# If the children are still running, terminate them:
					self.terminate
					
					# Wait for the children to exit:
					self.wait_for_exit(clock, terminate_timeout)
				end
				
				if any?
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
							@running[io].resume
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
			
			def yield
				if @queue
					fiber = Fiber.current
					
					@queue << fiber
					Fiber.yield
				end
			end
			
			def suspend
				@queue ||= []
			end
			
			def resume
				if @queue
					queue = @queue
					@queue = nil
					
					queue.each(&:resume)
				end
			end
		end
	end
end
