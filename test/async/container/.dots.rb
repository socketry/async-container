#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

require_relative '../../../lib/async/container/controller'

$stdout.sync = true

class Dots < Async::Container::Controller
	def setup(container)
		container.run(name: "dots", count: 1, restart: true) do |instance|
			instance.ready!
			
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
