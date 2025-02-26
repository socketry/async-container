# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require_relative "client"
require "socket"

module Async
	module Container
		module Notify
			# Implements the systemd NOTIFY_SOCKET process readiness protocol.
			# See <https://www.freedesktop.org/software/systemd/man/sd_notify.html> for more details of the underlying protocol.
			class Socket < Client
				# The name of the environment variable which contains the path to the notification socket.
				NOTIFY_SOCKET = "NOTIFY_SOCKET"
				
				# The maximum allowed size of the UDP message.
				MAXIMUM_MESSAGE_SIZE = 4096
				
				# Open a notification client attached to the current {NOTIFY_SOCKET} if possible.
				def self.open!(environment = ENV)
					if path = environment.delete(NOTIFY_SOCKET)
						self.new(path)
					end
				end
				
				# Initialize the notification client.
				# @parameter path [String] The path to the UNIX socket used for sending messages to the process manager.
				def initialize(path)
					@path = path
					@address = Addrinfo.unix(path, ::Socket::SOCK_DGRAM)
				end
				
				# @attribute [String] The path to the UNIX socket used for sending messages to the controller.
				attr :path
				
				# Dump a message in the format requied by `sd_notify`.
				# @parameter message [Hash] Keys and values should be string convertible objects. Values which are `true`/`false` are converted to `1`/`0` respectively.
				def dump(message)
					buffer = String.new
					
					message.each do |key, value|
						# Conversions required by NOTIFY_SOCKET specifications:
						if value == true
							value = 1
						elsif value == false
							value = 0
						end
						
						buffer << "#{key.to_s.upcase}=#{value}\n"
					end
					
					return buffer
				end
				
				# Send the given message.
				# @parameter message [Hash]
				def send(**message)
					data = dump(message)
					
					if data.bytesize > MAXIMUM_MESSAGE_SIZE
						raise ArgumentError, "Message length #{data.bytesize} exceeds #{MAXIMUM_MESSAGE_SIZE}: #{message.inspect}"
					end
					
					@address.connect do |peer|
						peer.sendmsg(data)
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
