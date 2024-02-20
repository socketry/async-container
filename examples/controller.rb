#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Anton Sozontov.

require '../lib/async/container/controller'

class Controller < Async::Container::Controller
  def setup(container)
    container.run(count: 1, restart: true) do |instance|
      if container.statistics.failed?
        Console.logger.debug(self, "Child process restarted #{container.statistics.restarts} times.")
      else
        Console.logger.debug(self, "Child process started.")
      end

      instance.ready!

      while true
        sleep 1

        Console.logger.debug(self, "Work")

        if rand < 0.5
          Console.logger.debug(self, "Should exit...")
          sleep 0.5
          exit(1)
        end
      end
    end
  end
end

Console.logger.debug!

Console.logger.debug(self, "Starting up...")

controller = Controller.new

controller.run
