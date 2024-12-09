#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2019, by Yuji Yaginuma.
# Copyright, 2022, by Anton Sozontov.

require "../lib/async/container"

Console.logger.debug!

container = Async::Container.new

Console.debug "Spawning 2 containers..."

2.times do
	container.spawn do |task|
		Console.debug task, "Sleeping..."
		sleep(2)
		Console.debug task, "Waking up!"
	end
end

Console.debug "Waiting for container..."
container.wait
Console.debug "Finished."
