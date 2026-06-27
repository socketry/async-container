# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "events"

module Async
	module Container
		# Represents a collection of process signal handlers which enqueue events.
		class Signals
			# Represents a trapped signal event.
			class Event
				# Initialize the signal event.
				# @parameter signal [Symbol | String | Integer] The signal that was received.
				# @parameter handler [Proc] The handler to invoke when the event is applied.
				def initialize(signal, handler)
					@signal = signal
					@handler = handler
				end
				
				# @attribute [Symbol | String | Integer] The signal that was received.
				attr :signal
				
				# Call the signal event by invoking its handler.
				def call
					@handler.call
				end
			end
			
			# Initialize the signal handler collection.
			# @parameter events [Events] The queue used to receive signal events.
			def initialize(events = Events.new)
				@events = events
				@handlers = {}
			end
			
			# @attribute [Events] The queue used to receive signal events.
			attr :events
			
			# Register a signal handler.
			# If no block is provided, the signal will be ignored while trapped.
			# @parameter signal [Symbol | String | Integer] The signal to trap.
			def trap(signal, &block)
				@handlers[signal] = block
			end
			
			# Ignore a signal while trapped.
			# @parameter signal [Symbol | String | Integer] The signal to ignore.
			def ignore(signal)
				trap(signal)
			end
			
			# Wait for the next signal event.
			# @returns [Event] The next signal event.
			def wait
				@events.pop
			end
			
			# Install the registered signal handlers for the duration of the block.
			# @yields {|signals| ...} The block to run while signal handlers are installed.
			def trapped
				previous = {}
				
				@handlers.each do |signal, handler|
					previous[signal] = install(signal, handler)
				end
				
				yield self
			ensure
				previous&.each do |signal, handler|
					::Signal.trap(signal, handler)
				end
			end
			
			private
			
			def install(signal, handler)
				if handler
					::Signal.trap(signal) do
						@events << Event.new(signal, handler)
					end
				else
					::Signal.trap(signal, "IGNORE")
				end
			end
		end
	end
end
