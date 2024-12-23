# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "tmpdir"
require "securerandom"

module Async
	module Container
		module Notify
			class Server
				MAXIMUM_MESSAGE_SIZE = 4096
				
				def self.load(message)
					lines = message.split("\n")
					
					lines.pop if lines.last == ""
					
					pairs = lines.map do |line|
						key, value = line.split("=", 2)
						
						if value == "0"
							value = false
						elsif value == "1"
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
						@bound = Addrinfo.unix(@path, ::Socket::SOCK_DGRAM).bind
						
						@state = {}
					end
					
					def close
						@bound.close
						
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
