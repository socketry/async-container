#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require_relative "../../../../lib/async/container/controller"

$stdout.sync = true

class Graceful < Async::Container::Controller
	def setup(container)
		container.run(name: "graceful", count: 1, restart: true) do |instance|
			$stdout.puts "Ready..."
			instance.ready!
			
			sleep
		ensure
			$stdout.puts "Exiting..."
		end
	end
end

controller = Graceful.new

begin
	controller.run
rescue Interrupt
	$stdout.puts "Interrupted..."
end
