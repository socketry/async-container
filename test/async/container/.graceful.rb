#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

require_relative '../../../lib/async/container/controller'

class Graceful < Async::Container::Controller
	def setup(container)
		container.run(name: "graceful", count: 1, restart: true) do |instance|
			instance.ready!
			clock = Async::Clock.start
			
			original_action = Signal.trap(:INT) do
				$stdout.puts "Graceful shutdown...", clock.total
				$stdout.flush
				
				Signal.trap(:INT, original_action)
			end
			
			$stdout.puts "Ready...", clock.total
			$stdout.flush
			
			sleep
		ensure
			$stdout.puts "Exiting...", clock.total
			$stdout.flush
		end
	end
end

controller = Graceful.new(graceful_stop: 1)

controller.run
