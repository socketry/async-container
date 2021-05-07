#!/usr/bin/env ruby
# frozen_string_literal: true

require '../lib/async/container/controller'
require '../lib/async/container/forked'

Console.logger.debug!

Console.logger.debug(self, "Starting up...")

controller = Async::Container::Controller.new do |container|
	Console.logger.debug(self, "Setting up container...")
	
	container.run(count: 1, restart: true) do
		Console.logger.debug(self, "Child process started.")
		
		while true
			sleep 1
			
			if rand < 0.1
				exit(1)
			end
		end
	ensure
		Console.logger.debug(self, "Child process exiting:", $!)
	end
end

begin
	controller.run
ensure
	Console.logger.debug(controller, "Parent process exiting:", $!)
end
