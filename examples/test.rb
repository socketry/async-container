# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

require_relative 'group'
require_relative 'thread'
require_relative 'process'

group = Async::Container::Group.new

thread_monitor = Fiber.new do
	while true
		thread = Async::Container::Thread.fork do |instance|
			if rand < 0.2
				raise "Random Failure!"
			end
			
			instance.send(ready: true, status: "Started Thread")
			
			sleep(1)
		end
		
		status = group.wait_for(thread) do |message|
			puts "Thread message: #{message}"
		end
		
		puts "Thread status: #{status}"
	end
end.resume

process_monitor = Fiber.new do
	while true
		# process = Async::Container::Process.fork do |instance|
		# 	if rand < 0.2
		# 		raise "Random Failure!"
		# 	end
		# 
		# 	instance.send(ready: true, status: "Started Process")
		# 
		# 	sleep(1)
		# end
		
		process = Async::Container::Process.spawn('bash -c "sleep 1; echo foobar; sleep 1; exit -1"')
		
		status = group.wait_for(process) do |message|
			puts "Process message: #{message}"
		end
		
		puts "Process status: #{status}"
	end
end.resume

group.wait
