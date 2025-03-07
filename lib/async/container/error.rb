# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

module Async
	module Container
		# Represents an error that occured during container execution.
		class Error < StandardError
		end
		
		Interrupt = ::Interrupt
		
		# Similar to {Interrupt}, but represents `SIGTERM`.
		class Terminate < SignalException
			SIGTERM = Signal.list["TERM"]
			
			# Create a new terminate error.
			def initialize
				super(SIGTERM)
			end
		end
		
		# Similar to {Interrupt}, but represents `SIGHUP`.
		class Restart < SignalException
			SIGHUP = Signal.list["HUP"]
			
			# Create a new restart error.
			def initialize
				super(SIGHUP)
			end
		end
		
		# Represents the error which occured when a container failed to start up correctly.
		class SetupError < Error
			# Create a new setup error.
			#
			# @parameter container [Generic] The container that failed.
			def initialize(container)
				super("Could not create container!")
				
				@container = container
			end
			
			# @attribute [Generic] The container that failed.
			attr :container
		end
	end
end
