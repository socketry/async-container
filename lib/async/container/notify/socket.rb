# frozen_string_literal: true

#
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
			class Socket < Client
				NOTIFY_SOCKET = 'NOTIFY_SOCKET'
				MAXIMUM_MESSAGE_SIZE = 4096
				
				def self.open!(environment = ENV)
					if path = environment.delete(NOTIFY_SOCKET)
						self.new(path)
					end
				end
				
				def initialize(path)
					@path = path
					@endpoint = IO::Endpoint.unix(path, ::Socket::SOCK_DGRAM)
				end
				
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
					
					buffer
				end
				
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
				
				def error!(text, **message)
					message[:errno] ||= -1
					
					send(status: text, **message)
				end
			end
		end
	end
end
