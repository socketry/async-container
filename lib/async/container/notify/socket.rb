# frozen_string_literal: true

# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'client'

require 'async/io'
require 'async/io/unix_endpoint'
require 'kernel/sync'

module Async
	module Container
		module Notify
			# Implements the systemd NOTIFY_SOCKET process readiness protocol.
			# See <https://www.freedesktop.org/software/systemd/man/sd_notify.html> for more details of the underlying protocol.
			class Socket < Client
				# The name of the environment variable which contains the path to the notification socket.
				NOTIFY_SOCKET = 'NOTIFY_SOCKET'
				
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
					@endpoint = IO::Endpoint.unix(path, ::Socket::SOCK_DGRAM)
				end
				
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
						raise ArgumentError, "Message length #{message.bytesize} exceeds #{MAXIMUM_MESSAGE_SIZE}: #{message.inspect}"
					end
					
					Sync do
						@endpoint.connect do |peer|
							peer.send(data)
						end
					end
				end
				
				# Send the specified error.
				# `sd_notify` requires an `errno` key, which defaults to `-1` to indicate a generic error.
				def error!(text, **message)
					message[:errno] ||= -1
					
					send(status: text, **message)
				end
			end
		end
	end
end
