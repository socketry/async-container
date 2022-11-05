#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

require_relative '../../../../lib/async/container'

class MyController < Async::Container::Controller
	def setup(container)
		container.run(restart: false) do |instance|
			sleep(rand)
			
			instance.ready!
			
			sleep(rand)
		end
	end
end

controller = MyController.new
controller.run
