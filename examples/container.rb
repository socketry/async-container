#!/usr/bin/env ruby

require 'async/container/forked'

container = Async::Container::Forked.new

puts "Controller process: #{Process.pid}"

container.run(processes: 8, restart: true) do
	puts "Starting process: #{Process.pid}"
	
	while true
		sleep 1
	end
ensure
	puts "Exiting: #{$!}"
end

container.wait

puts "Controller procss exiting!"
