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

require 'async/io'
require 'async/io/unix_endpoint'
require 'kernel/sync'

require 'tmpdir'
require 'securerandom'

module Async
	module Container
		module Notify
			NOTIFY_SOCKET = 'NOTIFY_SOCKET'
			MAXIMUM_MESSAGE_SIZE = 4096
			
			def self.load(message)
				lines = message.split("\n")
				
				return Hash[
					lines.map{|line| line.split("=", 2)}
				]
			end
			
			# Sets or clears NOTIFY_SOCKET environment variable depending on whether the server exists (and in theory bound).
			def self.after_fork(server, environment = ENV)
				if server
					# Set the environment variable:
					environment[NOTIFY_SOCKET] = server.path
				else
					# Unset the environment variable (this doesn't actually set it to nil):
					environment[NOTIFY_SOCKET] = nil
				end
				
				return environment
			end
			
			# Inserts or duplicates the environment given an argument array.
			# Sets or clears it in a way that is suitable for {::Process.spawn}.
			def self.before_spawn(server, arguments)
				if arguments.first.is_a?(Hash)
					environment = arguments.first = arguments.first.dup
				else
					arguments.unshift(environment = Hash.new)
				end
				
				after_fork(server, arguments.first)
				
				return arguments
			end
			
			class Client
				def self.open(path = ENV[NOTIFY_SOCKET])
					if path
						self.new(
							IO::Endpoint.unix(path, Socket::SOCK_DGRAM)
						)
					end
				end
				
				def initialize(endpoint, pid: Process.pid)
					@endpoint = endpoint
					@pid = pid
				end
				
				def send(message)
					if message.bytesize > MAXIMUM_MESSAGE_SIZE
						raise ArgumentError, "Message length #{message.bytesize} exceeds #{MAXIMUM_MESSAGE_SIZE}: #{message.inspect}"
					end
					
					Sync do
						@endpoint.connect do |peer|
							peer.send(message)
						end
					end
				end
				
				def ready!(status = "Ready...")
					send("PID=#{@pid}\nREADY=1\nSTATUS=#{status}")
				end
				
				def reloading!(status = "Reloading...")
					send("PID=#{@pid}\nRELOADING=1\nSTATUS=#{status}")
				end
				
				def restarting!(status = "Restarting...")
					send("PID=#{@pid}\nRELOADING=1\nSTATUS=#{status}")
				end
				
				def stopping!
					send("PID=#{@pid}\nSTOPPING=1")
				end
				
				def status!(text)
					send("PID=#{@pid}\nSTATUS=#{text}")
				end
				
				def error!(status, errno: -1)
					send("PID=#{@pid}\nERRNO=#{errno}\nSTATUS=#{status}")
				end
			end
			
			class Server
				def self.generate_path
					File.expand_path(
						"async-container-#{Process.pid}-#{SecureRandom.hex(8)}.ipc",
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
						@endpoint = IO::Endpoint.unix(@path, Socket::SOCK_DGRAM)
						
						Sync do
							@bound = @endpoint.bind
						end
						
						@state = {}
						@status = {}
					end
					
					def clear
						@state.clear
						@status.clear
					end
					
					def pids
						@state.keys
					end
					
					def add(pid)
						@state[pid] = :preparing
					end
					
					def fail(pid, reason = nil)
						@state[pid] = :failed
						@status[pid] = reason
					end
					
					def remove(pid)
						@state.delete(pid)
						@status.delete(pid)
					end
					
					attr :state
					attr :status
					
					def update(pid, message)
						if status = message['STATUS']
							@status[pid] = status
						end
						
						if message['RELOADING'] == '1'
							@state[pid] = :preparing
						end
						
						if message['READY'] == '1'
							@state[pid] = :ready
						end
						
						if message['STOPPING'] == '1'
							@state[pid] = :stopping
						end
					end
					
					def ready?(pids)
						self.pids.all?{|pid| @state[pid] != :preparing}
					end
					
					def close
						Sync do
							@bound.close
						end
						
						File.unlink(@path)
					end
					
					def receive
						while true
							data, address, flags, *controls = @bound.recvmsg(MAXIMUM_MESSAGE_SIZE)
							
							message = Notify.load(data)
							
							if pid = message['PID']&.to_i
								update(pid, message)
							end
							
							yield message
						end
					end
				end
			end
		end
	end
end
