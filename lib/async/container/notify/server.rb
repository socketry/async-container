# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "tmpdir"
require "socket"
require "securerandom"

module Async
	module Container
		module Notify
			# A simple UDP server that can be used to receive messages from a child process, tracking readiness, status changes, etc.
			class Server
				MAXIMUM_MESSAGE_SIZE = 4096
				
				# Parse a message, according to the `sd_notify` protocol.
				#
				# @parameter message [String] The message to parse.
				# @returns [Hash] The parsed message.
				def self.load(message)
					lines = message.split("\n")
					
					lines.pop if lines.last == ""
					
					pairs = lines.map do |line|
						key, value = line.split("=", 2)
						
						key = key.downcase.to_sym
						
						if value == "0"
							value = false
						elsif value == "1"
							value = true
						elsif key == :errno and value =~ /\A\-?\d+\z/
							value = Integer(value)
						end
						
						next [key, value]
					end
					
					return Hash[pairs]
				end
				
				# Generate a new unique path for the UNIX socket.
				#
				# @returns [String] The path for the UNIX socket.
				def self.generate_path
					File.expand_path(
						"async-container-#{::Process.pid}-#{SecureRandom.hex(8)}.ipc",
						Dir.tmpdir
					)
				end
				
				# Open a new server instance with a temporary and unique path.
				def self.open(path = self.generate_path)
					self.new(path)
				end
				
				# Initialize the server with the given path.
				#
				# @parameter path [String] The path to the UNIX socket.
				def initialize(path)
					@path = path
				end
				
				# @attribute [String] The path to the UNIX socket.
				attr :path
				
				# Generate a bound context for receiving messages.
				#
				# @returns [Context] The bound context.
				def bind
					Context.new(@path)
				end
				
				# A bound context for receiving messages.
				class Context
					# Initialize the context with the given path.
					#
					# @parameter path [String] The path to the UNIX socket.
					def initialize(path)
						@path = path
						@bound = Addrinfo.unix(@path, ::Socket::SOCK_DGRAM).bind
						
						@state = {}
					end
					
					# Close the bound context.
					def close
						@bound.close
						
						File.unlink(@path)
					end
					
					# Receive a message from the bound context.
					#
					# @returns [Hash] The parsed message.
					def receive
						while true
							data, _address, _flags, *_controls = @bound.recvmsg(MAXIMUM_MESSAGE_SIZE)
							
							message = Server.load(data)
							
							if block_given?
								yield message
							else
								return message
							end
						end
					end
				end
			end
		end
	end
end
