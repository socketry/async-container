
require 'async/container'

require 'async/http/endpoint'
require 'async/http/server'
require 'async/io/shared_endpoint'

container = Async::Container::Forked.new

endpoint = Async::HTTP::Endpoint.parse("http://localhost:9292")

bound_endpoint = Async::Reactor.run do
	Async::IO::SharedEndpoint.bound(endpoint)
end.wait

input, output = Async::IO.pipe
input.write(".")

Async.logger.info(endpoint) {"Bound to #{bound_endpoint.inspect}"}

GC.start
GC.compact if GC.respond_to?(:compact)

container.run(count: 16, restart: true) do
	Async do |task|
		server = Async::HTTP::Server.for(bound_endpoint, endpoint.protocol, endpoint.scheme) do |request|
			Protocol::HTTP::Response[200, {}, ["Hello World"]]
		end
		
		output.read(1)
		Async.logger.info(server) {"Starting server..."}
		output.write(".")
		
		server.run
		
		task.children.each(&:wait)
	end
end

container.wait
