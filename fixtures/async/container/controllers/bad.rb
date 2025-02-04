#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "../../../../lib/async/container/controller"

$stdout.sync = true

class Bad < Async::Container::Controller
	def setup(container)
		container.run(name: "bad", count: 1, restart: true) do |instance|
			# Deliberately missing call to `instance.ready!`:
			# instance.ready!
			
			$stdout.puts "Ready..."
			
			sleep
		ensure
			$stdout.puts "Exiting..."
		end
	end
end

controller = Bad.new

controller.run
