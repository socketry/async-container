#!/usr/bin/env ruby
# frozen_string_literal: true

require "async/container"
require "console"

require "io/endpoint/host_endpoint"
require "io/endpoint/bound_endpoint"

# Console.logger.debug!

class Application < Async::Container::Controller
	def endpoint
		IO::Endpoint.tcp("0.0.0.0", 9292)
	end
	
	def bound_socket
		bound = endpoint.bound
		
		bound.sockets.each do |socket|
			socket.listen(Socket::SOMAXCONN)
		end
		
		return bound
	end
	
	def setup(container)
		@bound = bound_socket
		
		container.spawn(name: "Web", restart: true) do |instance|
			env = ENV.to_h
			
			@bound.sockets.each_with_index do |socket, index|
				env["PUMA_INHERIT_#{index}"] = "#{socket.fileno}:tcp://0.0.0.0:9292"
			end
			
			instance.exec(env, "bundle", "exec", "puma", "-C", "puma.rb", ready: false)
		end
	end
end

application = Application.new
application.run
