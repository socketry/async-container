#!/usr/bin/env ruby

require_relative '../../../../lib/async/container'

class MyController < Async::Container::Controller
	def setup(container)
		container.run(restart: false) do |instance|
			sleep(rand(1..8))
			
			instance.ready!
			
			sleep(1)
		end
	end
end

controller = MyController.new
controller.run
