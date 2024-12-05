#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "../../../lib/async/container/controller"

$stdout.sync = true

class Pwd < Async::Container::Controller
	def setup(container)
		container.spawn do |instance|
			instance.ready!
			
			instance.exec("pwd", chdir: "/")
		end
	end
end

controller = Pwd.new

controller.run
