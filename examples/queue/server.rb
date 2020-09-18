
require 'async'
require 'async/container'
require 'async/io/unix_endpoint'
require 'async/io/shared_endpoint'
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

endpoint = Async::IO::Endpoint.unix('test.ipc')
wrapper = Wrapper.new

container = Async::Container.new

bound_endpoint = Sync do
	Async::IO::SharedEndpoint.bound(endpoint)
end

container.spawn do |instance|
	Async do
		queue = 500_000.times.to_a
		Console.logger.info(self) {"Hosting the queue..."}
		
		instance.ready!
		
		bound_endpoint.accept do |peer|
			Console.logger.info(self) {"Incoming connection from #{peer}..."}
			
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
					# Console.logger.info("Job Status") {arguments}
				else
					Console.logger.warn(self) {"Unhandled command: #{command}#{arguments.inspect}"}
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
					Console.logger.warn(self) {"Unhandled command: #{command}#{arguments.inspect}"}
				end
			end
		end
	end
end

container.wait

Console.logger.info(self) {"Done!"}
