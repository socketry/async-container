#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

require 'async/io'
require 'async/io/endpoint'
require 'async/io/unix_endpoint'

@endpoint = Async::IO::Endpoint.unix("/tmp/notify-test.sock", Socket::SOCK_DGRAM)
# address = Async::IO::Address.udp("127.0.0.1", 6778)
# @endpoint = Async::IO::AddressEndpoint.new(address)

def server
	@endpoint.bind do |server|
		puts "Receiving..."
		packet, address = server.recvfrom(512)
		
		puts "Received: #{packet} from #{address}"
	end
end

def client(data = "Hello World!")
	@endpoint.connect do |peer|
		puts "Sending: #{data}"
		peer.send(data)
		puts "Sent!"
	end
end

Async do |task|
	server_task = task.async do
		server
	end
	
	client
end
