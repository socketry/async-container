#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "metrics"
require_relative "../../lib/async/container/controller"

NAMES = [
	"Cupcake", "Donut", "Eclair", "Froyo", "Gingerbread", "Honeycomb", "Ice Cream Sandwich", "Jelly Bean", "KitKat", "Lollipop", "Marshmallow", "Nougat", "Oreo", "Pie", "Apple Tart"
]

class Controller < Async::Container::Controller
	def setup(container)
		container.run(count: 10, restart: true, health_check_timeout: 1) do |instance|
			if container.statistics.failed?
				Console.debug(self, "Child process restarted #{container.statistics.restarts} times.")
			else
				Console.debug(self, "Child process started.")
			end
			
			instance.name = NAMES.sample
			
			instance.ready!
			
			while true
				# Must update status more frequently than health check timeout...
				sleep(rand*1.2)
				
				instance.ready!
			end
		end
	end
end

controller = Controller.new # (container_class: Async::Container::Threaded)

controller.run
