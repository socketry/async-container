#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

require_relative '../../../lib/async/container/controller'

class Bad < Async::Container::Controller
	def setup(container)
		container.run(name: "bad", count: 1, restart: true) do |instance|
			# Deliberately missing call to `instance.ready!`:
			# instance.ready!
			
			$stdout.puts "Ready..."
			$stdout.flush
			
			sleep
		ensure
			$stdout.puts "Exiting..."
			$stdout.flush
		end
	end
end

controller = Bad.new

controller.run
