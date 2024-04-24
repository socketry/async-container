#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

require 'async'
require 'async/container'
require 'io/endpoint'
require 'io/endpoint/unix_endpoint'
require 'msgpack'

class Wrapper < MessagePack::Factory
	def initialize
		super()
		
		# self.register_type(0x00, Object, packer: @bus.method(:temporary), unpacker: @bus.method(:[]))
		
		self.register_type(0x01, Symbol)
		self.register_type(0x02, Exception,
			packer: ->(exception){Marshal.dump(exception)},
			unpacker: ->(data){Marshal.load(data)},
		)
		
		self.register_type(0x03, Class,
			packer: ->(klass){Marshal.dump(klass)},
			unpacker: ->(data){Marshal.load(data)},
		)
	end
end

endpoint = IO::Endpoint.unix('test.ipc')
bound_endpoint = endpoint.bound

wrapper = Wrapper.new

container = Async::Container.new

container.spawn do |instance|
	Async do
		queue = 500_000.times.to_a
		Console.info(self) {"Hosting the queue..."}
		
		instance.ready!
		
		bound_endpoint.accept do |peer|
			Console.info(self) {"Incoming connection from #{peer}..."}
			
			packer = wrapper.packer(peer)
			unpacker = wrapper.unpacker(peer)
			
			unpacker.each do |message|
				command, *arguments = message
				
				case command
				when :ready
					if job = queue.pop
						packer.write([:job, job])
						packer.flush
					else
						peer.close_write
						break
					end
				when :status
					Console.info("Job Status") {arguments}
				else
					Console.warn(self) {"Unhandled command: #{command}#{arguments.inspect}"}
				end
			end
		end
	end
end

container.run do |instance|
	Async do |task|
		endpoint.connect do |peer|
			instance.ready!
			
			packer = wrapper.packer(peer)
			unpacker = wrapper.unpacker(peer)
			
			packer.write([:ready])
			packer.flush
			
			unpacker.each do |message|
				command, *arguments = message
				
				case command
				when :job
					# task.sleep(*arguments)
					packer.write([:status, *arguments])
					packer.write([:ready])
					packer.flush
				else
					Console.warn(self) {"Unhandled command: #{command}#{arguments.inspect}"}
				end
			end
		end
	end
end

container.wait

Console.info(self) {"Done!"}
