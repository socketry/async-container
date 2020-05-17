#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../../lib/async/container/controller'

# Console.logger.debug!

class Dots < Async::Container::Controller
	def setup(container)
		container.run(name: "dots", count: 1, restart: true) do |instance|
			instance.ready!
			
			sleep 1
			
			$stdout.write "."
			$stdout.flush
			
			sleep
		rescue Async::Container::Interrupt
			$stdout.write("I")
		rescue Async::Container::Terminate
			$stdout.write("T")
		end
	end
end

controller = Dots.new

controller.run
