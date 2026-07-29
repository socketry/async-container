# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/deadline"

require_relative "channel"
require_relative "error"

module Async
	module Container
		# Represents a child execution unit managed by a container.
		class Child
			# The default amount of time to wait for a child to be reaped after its
			# notification channel closes.
			REAP_TIMEOUT = 1.0
			
			# Initialize the child with the given notification channel.
			# @parameter channel [Channel] The channel used to receive child notifications.
			# @parameter name [String | Nil] The optional child name.
			# @parameter options [Hash] Additional child options.
			def initialize(channel, name: nil, **options)
				@channel = channel
				@name = name
				@options = options
				@state = {}
				@last_updated_at = Clock.now
			end
			
			# @attribute [Channel] The channel for the child.
			attr :channel
			
			# @attribute [String] The name for the child.
			attr :name
			
			# @attribute [Hash] The current child state, derived from notification messages.
			attr :state
			
			# @attribute [Float] The last time the child sent a message.
			attr :last_updated_at
			
			# Whether the child has reported readiness.
			def ready?
				@state[:ready] == true
			end
			
			# Update the child state from a notification message.
			def update(message)
				@state.update(message)
				@last_updated_at = Clock.now
			end
			
			# Stop the child with a multi-phase shutdown sequence.
			#
			# A graceful shutdown sends an interrupt first and waits up to `graceful`
			# seconds. If the child is still running, or if graceful shutdown is
			# disabled, the child is killed and waited for indefinitely.
			#
			# @parameter graceful [Boolean | Numeric] Whether to send an interrupt first or skip directly to kill.
			def stop(graceful = true, &block)
				status = nil
				
				if graceful
					self.interrupt!
					
					timeout = (graceful == true) ? nil : graceful
					status = self.wait(timeout, &block)
				end
				
				return status if status
			ensure
				unless status
					self.kill!
					status = self.wait(nil, &block)
				end
				
				return status
			end
			
			# Receive notification messages from the child until a message is available, the channel closes, or the timeout expires.
			# @parameter timeout [Numeric | Nil] The maximum time to wait for a message.
			# @yields {|message| ...} Each received notification message.
			# 	@parameter message [Hash] The notification message from the child.
			# @returns [Hash | Boolean | Nil] The message, `false` on timeout, or `nil` when the channel closes.
			def receive(timeout = nil, &block)
				deadline = Deadline.new(timeout) if timeout
				
				while true
					if timeout
						if deadline.expired?
							return false
						end
						
						unless @channel.in.wait_readable(deadline.remaining)
							return false
						end
					else
						@channel.in.wait_readable
					end
					
					if message = @channel.receive
						self.update(message)
						if block_given?
							yield message
						else
							return message
						end
					else
						return nil
					end
				end
			end
			
			# Drain notification messages until the channel closes or the timeout expires.
			#
			# @parameter timeout [Numeric | Nil] Maximum time to wait before returning `nil`.
			# @returns [Object | Nil] The child status if the child exited, otherwise `nil` on timeout.
			def wait(timeout = nil, &block)
				deadline = Deadline.new(timeout) if timeout
				
				result = if block
					receive(timeout, &block)
				else
					receive(timeout) do
						# Drain messages until the child exits.
					end
				end
				
				case result
				when false
					return nil
				when nil
					timeout = deadline&.remaining || REAP_TIMEOUT
					status = self.reap(timeout)
					
					unless status
						self.kill!
						status = self.reap
					end
					
					return status
				else
					# The block broke early, so the child may still be running.
					return nil
				end
			end
			
			# Reap the child after the channel has closed.
			def reap(timeout = nil)
				raise NotImplementedError
			end
			
			# Interrupt the child, initiating graceful shutdown.
			def interrupt!
				raise NotImplementedError
			end
			
			# Terminate the child.
			def terminate!
				raise NotImplementedError
			end
			
			# Kill the child.
			def kill!
				raise NotImplementedError
			end
			
			# Restart the child.
			def restart!
				raise NotImplementedError
			end
		end
	end
end
