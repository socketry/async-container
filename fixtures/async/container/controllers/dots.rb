#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "../../../../lib/async/container/controller"

$stdout.sync = true

class Dots < Async::Container::Controller
	def setup(container)
		container.run(name: "dots", count: 1, restart: true) do |instance|			
			instance.ready!
			
			# This helps prevent race conditions in the tests:
			sleep 0.01
			
			$stdout.write "."
			
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
