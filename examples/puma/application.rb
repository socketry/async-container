#!/usr/bin/env ruby
# frozen_string_literal: true

require "async/container"
require "console"

# Console.logger.debug!

class Application < Async::Container::Controller
	def setup(container)
		container.spawn(name: "Web", restart: true) do |instance|
			pid = ::Process.spawn("puma")
			
			instance.ready!
			
			begin
				status = ::Process.wait2(pid)
			rescue Async::Container::Hangup
				Console.warn(self, "Restarting puma...")
				::Process.kill("USR1", pid)
				retry
			ensure
				::Process.kill("TERM", pid)
			end
		end
	end
end

Application.new.run
