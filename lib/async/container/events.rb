# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Async
	module Container
		# Represents a queue of events that can wake `IO.select`.
		class Events
			# Initialize the event queue.
			def initialize
				@queue = ::Thread::Queue.new
				@input, @output = ::IO.pipe
				@io = @input
			end
			
			# @attribute [IO] The readable end of the event pipe.
			attr :input
			
			# @attribute [IO] The readable end used to wait for events.
			attr :io
			
			# Enqueue an event and wake any waiter.
			# @parameter event [Object] The event to enqueue.
			def <<(event)
				@queue << event
				
				begin
					@output.write_nonblock(".")
				rescue ::IO::WaitWritable
					# The pipe is already full, so any select waiter is already awake:
				end
				
				return self
			end
			
			# Remove and return the next queued event.
			# @parameter non_block [Boolean] Whether to raise if no event is ready.
			# @parameter timeout [Numeric | Nil] The maximum time to wait for an event.
			def pop(non_block = false, timeout: nil)
				if timeout
					event = @queue.pop(non_block, timeout: timeout)
				else
					event = @queue.pop(non_block)
				end
				
				return unless event
				
				@input.read_nonblock(1)
				
				return event
			rescue ::IO::WaitReadable
				return event if event
				
				raise
			end
		end
	end
end
