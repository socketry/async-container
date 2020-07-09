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

require 'async/io'
require 'async/io/unix_endpoint'
require 'kernel/sync'

require 'tmpdir'
require 'securerandom'

module Async
	module Container
		module Notify
			class Server
				NOTIFY_SOCKET = 'NOTIFY_SOCKET'
				MAXIMUM_MESSAGE_SIZE = 4096
				
				def self.load(message)
					lines = message.split("\n")
					
					lines.pop if lines.last == ""
					
					pairs = lines.map do |line|
						key, value = line.split("=", 2)
						
						if value == '0'
							value = false
						elsif value == '1'
							value = true
						end
						
						next [key.downcase.to_sym, value]
					end
					
					return Hash[pairs]
				end
				
				def self.generate_path
					File.expand_path(
						"async-container-#{::Process.pid}-#{SecureRandom.hex(8)}.ipc",
						Dir.tmpdir
					)
				end
				
				def self.open(path = self.generate_path)
					self.new(path)
				end
				
				def initialize(path)
					@path = path
				end
				
				attr :path
				
				def bind
					Context.new(@path)
				end
				
				class Context
					def initialize(path)
						@path = path
						@endpoint = IO::Endpoint.unix(@path, ::Socket::SOCK_DGRAM)
						
						Sync do
							@bound = @endpoint.bind
						end
						
						@state = {}
					end
					
					def close
						Sync do
							@bound.close
						end
						
						File.unlink(@path)
					end
					
					def receive
						while true
							data, _address, _flags, *_controls = @bound.recvmsg(MAXIMUM_MESSAGE_SIZE)
							
							message = Server.load(data)
							
							yield message
						end
					end
				end
			end
		end
	end
end
