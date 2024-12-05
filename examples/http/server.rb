#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "async/container"

require "async/http/endpoint"
require "async/http/server"

container = Async::Container::Forked.new

endpoint = Async::HTTP::Endpoint.parse("http://localhost:9292")
bound_endpoint = Sync{endpoint.bound}

Console.info(endpoint) {"Bound to #{bound_endpoint.inspect}"}

GC.start
GC.compact if GC.respond_to?(:compact)

container.run(count: 16, restart: true) do
	Async do |task|
		server = Async::HTTP::Server.for(bound_endpoint, protocol: endpoint.protocol, scheme: endpoint.scheme) do |request|
			Protocol::HTTP::Response[200, {}, ["Hello World"]]
		end
		
		Console.info(server) {"Starting server..."}
		
		server.run
		
		task.children.each(&:wait)
	end
end

container.wait
