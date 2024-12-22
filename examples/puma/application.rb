#!/usr/bin/env ruby
# frozen_string_literal: true

require "async/container"
require "console"

# Console.logger.debug!

class Application < Async::Container::Controller
	def setup(container)
		container.spawn(name: "Web") do |instance|
			instance.exec("bundle", "exec", "puma", "-C", "puma.rb", ready: false)
		end
	end
end

Application.new.run
