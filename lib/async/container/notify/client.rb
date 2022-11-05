# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

module Async
	module Container
		# Handles the details of several process readiness protocols.
		module Notify
			class Client
				# Notify the parent controller that the child has become ready, with a brief status message.
				# @parameters message [Hash] Additional details to send with the message.
				def ready!(**message)
					send(ready: true, **message)
				end
				
				# Notify the parent controller that the child is reloading.
				# @parameters message [Hash] Additional details to send with the message.
				def reloading!(**message)
					message[:ready] = false
					message[:reloading] = true
					message[:status] ||= "Reloading..."
					
					send(**message)
				end
				
				# Notify the parent controller that the child is restarting.
				# @parameters message [Hash] Additional details to send with the message.
				def restarting!(**message)
					message[:ready] = false
					message[:reloading] = true
					message[:status] ||= "Restarting..."
					
					send(**message)
				end
				
				# Notify the parent controller that the child is stopping.
				# @parameters message [Hash] Additional details to send with the message.
				def stopping!(**message)
					message[:stopping] = true
					
					send(**message)
				end
				
				# Notify the parent controller of a status change.
				# @parameters text [String] The details of the status change.
				def status!(text)
					send(status: text)
				end
				
				# Notify the parent controller of an error condition.
				# @parameters text [String] The details of the error condition.
				# @parameters message [Hash] Additional details to send with the message.
				def error!(text, **message)
					send(status: text, **message)
				end
			end
		end
	end
end
