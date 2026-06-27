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
				
				# If the pipe is full, any select waiter is already awake:
				@output.write_nonblock(".", exception: false)
				
				return self
			end
			
			# Remove and return the next queued event.
			def pop(...)
				event = @queue.pop(...)
				
				return unless event
				
				@input.read_nonblock(1, exception: false)
				
				return event
			end
		end
	end
end
