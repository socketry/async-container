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
			def initialize(health_check_interval: 1.0)
				@health_check_interval = health_check_interval
				
				@mutex = Mutex.new
				@children = {}
				@supervisors = 0
				@events = ::Thread::Queue.new
				
				@jobs = ::Thread::Queue.new
				@thread = nil
			end
			
			attr :health_check_interval
			
			def inspect
				"#<#{self.class} running=#{size}>"
			end
			
			def size
				@mutex.synchronize{@children.size}
			end
			
			def running?
				@mutex.synchronize{@supervisors.positive?}
			end
			
			def any?
				running?
			end
			
			def empty?
				!running?
			end
			
			# Compatibility for older tests/code that inspected the implementation.
			def running
				@mutex.synchronize{@children.dup}
			end
			
			def supervise(&block)
				@mutex.synchronize{@supervisors += 1}
				
				schedule do
					begin
						block.call
					ensure
						@mutex.synchronize{@supervisors -= 1}
						signal!
					end
				end
			end
			
			def insert(child)
				@mutex.synchronize{@children[child] = true}
			end
			
			def delete(child)
				@mutex.synchronize{@children.delete(child)}
				signal!
			end
			
			def sleep(duration = nil)
				::Thread.handle_interrupt(SignalException => :immediate) do
					@events.pop(timeout: duration)
				end
			end
			
			def wait
				sleep while running?
			end
			
			def health_check!
				signal!
			end
			
			def interrupt
				Console.info(self, "Sending interrupt to #{size} running children...")
				each_child(&:interrupt!)
			end
			
			def terminate
				Console.info(self, "Sending terminate to #{size} running children...")
				each_child(&:terminate!)
			end
			
			def kill
				Console.info(self, "Sending kill to #{size} running children...")
				each_child(&:kill!)
			end
			
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
			
			def schedule(&block)
				start_reactor
				
				@jobs << proc do |parent|
					parent.async(&block)
				end
			end
			
			def start_reactor
				return if @thread&.alive?
				
				@thread = ::Thread.new do
					Sync do |parent|
						while job = @jobs.pop
							job.call(parent)
						end
					end
				end
				
				@thread.report_on_exception = false
				@thread.name = "async-container supervisor"
			end
			
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
