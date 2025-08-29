#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2019, by Yuji Yaginuma.
# Copyright, 2022, by Anton Sozontov.

require_relative "../lib/async/container"

Console.logger.debug!

container = Async::Container.new

Console.debug "Spawning 2 children..."

2.times do
	container.spawn do |instance|
		Signal.trap(:INT) {}
		Signal.trap(:TERM) {}
		
		Console.debug instance, "Sleeping..."
		while true
			sleep
		end
		Console.debug instance, "Waking up!"
	end
end

Console.debug "Waiting for container..."
begin
	container.wait
rescue Interrupt
	# Okay, done.
ensure
	container.stop(true)
end
Console.debug "Finished."
