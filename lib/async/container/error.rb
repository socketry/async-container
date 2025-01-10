# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

module Async
	module Container
		class Error < StandardError
		end
		
		Interrupt = ::Interrupt
		
		# Similar to {Interrupt}, but represents `SIGTERM`.
		class Terminate < SignalException
			SIGTERM = Signal.list["TERM"]

			def initialize
				super(SIGTERM)
			end
		end
		
		class Restart < SignalException
			SIGHUP = Signal.list["HUP"]
			
			def initialize
				super(SIGHUP)
			end
		end
		
		# Represents the error which occured when a container failed to start up correctly.
		class SetupError < Error
			def initialize(container)
				super("Could not create container!")
				
				@container = container
			end
			
			# The container that failed.
			attr :container
		end
	end
end
