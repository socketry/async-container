# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require_relative "client"

require "console"

module Async
	module Container
		module Notify
			# Implements a general process readiness protocol with output to the local console.
			class Console < Client
				# Open a notification client attached to the current console.
				def self.open!(logger = ::Console)
					self.new(logger)
				end
				
				# Initialize the notification client.
				# @parameter logger [Console::Logger] The console logger instance to send messages to.
				def initialize(logger)
					@logger = logger
				end
				
				# Send a message to the console.
				def send(level: :info, **message)
					@logger.public_send(level, self) {message}
				end
				
				# Send an error message to the console.
				# @parameters text [String] The details of the error condition.
				# @parameters message [Hash] Additional details to send with the message.
				def error!(text, **message)
					send(status: text, level: :error, **message)
				end
			end
		end
	end
end
