#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require_relative "../../../../lib/async/container"

class MyController < Async::Container::Controller
	def setup(container)
		container.run(restart: false) do |instance|
			sleep(0.001)
			
			instance.ready!
			
			sleep(0.001)
		end
	end
end

controller = MyController.new
controller.run
