# frozen_string_literal: true

require 'msgpack'
require 'async/io'
require 'async/io/stream'
require 'async/container'

# class Bus
# 	def initialize
# 
# 	end
# 
# 	def << object
# 		:object
# 	end
# 
# 	def [] key
# 		return
# 	end
# end
#
# class Proxy < BasicObject
# 	def initialize(bus, name)
# 		@bus = bus
# 		@name = name
# 	end
# 
# 	def inspect
# 		"[Proxy #{method_missing(:inspect)}]"
# 	end
# 
# 	def method_missing(*args, &block)
# 		@bus.invoke(@name, args, &block)
# 	end
# 
# 	def respond_to?(*args)
# 		@bus.invoke(@name, ["respond_to?", *args])
# 	end
# end
# 
# class Wrapper < MessagePack::Factory
# 	def initialize(bus)
# 		super()
# 
# 		self.register_type(0x00, Object,
# 			packer: @bus.method(:<<),
# 			unpacker: @bus.method(:[])
# 		)
# 
# 		self.register_type(0x01, Symbol)
# 		self.register_type(0x02, Exception,
# 			packer: ->(exception){Marshal.dump(exception)},
# 			unpacker: ->(data){Marshal.load(data)},
# 		)
# 
# 		self.register_type(0x03, Class,
# 			packer: ->(klass){Marshal.dump(klass)},
# 			unpacker: ->(data){Marshal.load(data)},
# 		)
# 	end
# end
# 
# class Channel
# 	def self.pipe
# 		input, output = Async::IO.pipe
# 	end
# 
# 	def initialize(input, output)
# 		@input = input
# 		@output = output
# 	end
# 
# 	def read
# 		@input.read
# 	end
# 
# 	def write
# 	end
# end

container = Async::Container.new
input, output = Async::IO.pipe

container.async do |instance|
	stream = Async::IO::Stream.new(input)
	output.close
	
	while message = stream.gets
		puts "Hello World from #{instance}: #{message}"
	end
	
	puts "exiting"
end

stream = Async::IO::Stream.new(output)

5.times do |i|
	stream.puts "#{i}"
end

stream.close

container.wait
