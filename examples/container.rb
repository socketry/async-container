#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.
# Copyright, 2019, by Yuji Yaginuma.
# Copyright, 2022, by Anton Sozontov.

require '../lib/async/container'

Console.logger.debug!

container = Async::Container.new

Console.logger.debug "Spawning 2 containers..."

2.times do
	container.spawn do |task|
		Console.logger.debug task, "Sleeping..."
		sleep(2)
		Console.logger.debug task, "Waking up!"
	end
end

Console.logger.debug "Waiting for container..."
container.wait
Console.logger.debug "Finished."
