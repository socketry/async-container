#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require '../../lib/async/container'
require 'io/endpoint/host_endpoint'

Console.logger.debug!

module SignalWrapper
	def self.trap(signal, &block)
		signal = signal
		
		original = Signal.trap(signal) do
			::Signal.trap(signal, original)
			block.call
		end
	end
end

class Controller < Async::Container::Controller
	def initialize(...)
		super
		
		@endpoint = ::IO::Endpoint.tcp("localhost", 8080)
		@bound_endpoint = nil
	end
	
	def start
		Console.debug(self) {"Binding to #{@endpoint}"}
		@bound_endpoint = Sync{@endpoint.bound}
		
		super
	end
	
	def setup(container)
		container.run count: 2, restart: true do |instance|
			SignalWrapper.trap(:INT) do
				Console.debug(self) {"Closing bound instance..."}
				@bound_endpoint.close
			end
			
			Sync do |task|
				Console.info(self) {"Starting bound instance..."}
				
				instance.ready!
				
				@bound_endpoint.accept do |peer|
					while true
						peer.write("#{Time.now.to_s.rjust(32)}: Hello World\n")
						sleep 1
					end
				end
			end
		end
	end
	
	def stop(graceful = true)
		super
		
		if @bound_endpoint
			@bound_endpoint.close
			@bound_endpoint = nil
		end
	end
end

controller = Controller.new

controller.run
