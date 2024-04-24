#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative '../../../lib/async/container/controller'

$stdout.sync = true

class Graceful < Async::Container::Controller
	def setup(container)
		container.run(name: "graceful", count: 1, restart: true) do |instance|
			instance.ready!
			
			# This is to avoid race conditions in the controller in test conditions.
			sleep 0.1
			
			clock = Async::Clock.start
			
			original_action = Signal.trap(:INT) do
				# We ignore the int, but in practical applications you would want start a graceful shutdown.
				$stdout.puts "Graceful shutdown...", clock.total
				
				Signal.trap(:INT, original_action)
			end
			
			$stdout.puts "Ready...", clock.total
			
			sleep
		ensure
			$stdout.puts "Exiting...", clock.total
		end
	end
end

controller = Graceful.new(graceful_stop: 1)

begin
	controller.run
rescue Async::Container::Terminate
	$stdout.puts "Terminated..."
rescue Interrupt
	$stdout.puts "Interrupted..."
end
