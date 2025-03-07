# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require_relative "client"
require "socket"

module Async
	module Container
		module Notify
			# Represents a client that uses a local log file to communicate readiness, status changes, etc.
			class Log < Client
				# The name of the environment variable which contains the path to the notification socket.
				NOTIFY_LOG = "NOTIFY_LOG"
				
				# Open a notification client attached to the current {NOTIFY_LOG} if possible.
				def self.open!(environment = ENV)
					if path = environment.delete(NOTIFY_LOG)
						self.new(path)
					end
				end
				
				# Initialize the notification client.
				# @parameter path [String] The path to the UNIX socket used for sending messages to the process manager.
				def initialize(path)
					@path = path
				end
				
				# @attribute [String] The path to the UNIX socket used for sending messages to the controller.
				attr :path
				
				# Send the given message.
				# @parameter message [Hash]
				def send(**message)
					data = JSON.dump(message)
					
					File.open(@path, "a") do |file|
						file.puts(data)
					end
				end
				
				# Send the specified error.
				# `sd_notify` requires an `errno` key, which defaults to `-1` to indicate a generic error.
				def error!(text, **message)
					message[:errno] ||= -1
					
					super
				end
			end
		end
	end
end
