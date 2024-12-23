#!/usr/bin/env ruby
# frozen_string_literal: true

require "async/container"
require "console"

# Console.logger.debug!

class Application < Async::Container::Controller
	def setup(container)
		container.spawn(name: "Web", restart: true) do |instance|
			# Replace the current process with Puma:
			# instance.exec("bundle", "exec", "puma", "-C", "puma.rb", ready: false)
			
			# Manage a child process of puma / puma workers:
			pid = ::Process.spawn("puma", "-C", "puma.rb")
			
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
