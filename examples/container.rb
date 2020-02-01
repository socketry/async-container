#!/usr/bin/env ruby
# frozen_string_literal: true

require '../lib/async/container/controller'
require '../lib/async/container/forked'

Async.logger.debug!

Async.logger.debug(self, "Starting up...")

controller = Async::Container::Controller.new do |container|
	Async.logger.debug(self, "Setting up container...")
	
	container.run(count: 1, restart: true) do
		Async.logger.debug(self, "Child process started.")
		
		while true
			sleep 1
			
			if rand < 0.1
				exit(1)
			end
		end
	ensure
		Async.logger.debug(self, "Child process exiting:", $!)
	end
end

begin
	controller.run
ensure
	Async.logger.debug(controller, "Parent process exiting:", $!)
end
