#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Anton Sozontov.
# Copyright, 2024, by Samuel Williams.

require "../lib/async/container/controller"

class Controller < Async::Container::Controller
	def setup(container)
		container.run(count: 1, restart: true) do |instance|
			if container.statistics.failed?
				Console.debug(self, "Child process restarted #{container.statistics.restarts} times.")
			else
				Console.debug(self, "Child process started.")
			end

			instance.ready!

			while true
				sleep 1

				Console.debug(self, "Work")

				if rand < 0.5
					Console.debug(self, "Should exit...")
					sleep 0.5
					exit(1)
				end
			end
		end
	end
end

Console.logger.debug!

Console.debug(self, "Starting up...")

controller = Controller.new

controller.run
