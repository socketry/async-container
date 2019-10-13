#!/usr/bin/env ruby

puts "Process pid: #{Process.pid}"

threads = 10.times.collect do
	Thread.new do
		begin
			sleep
		rescue Exception
			puts "Thread: #{$!}"
		end
	end
end

while true
	begin
		threads.each(&:join)
		exit(0)
	rescue Exception
		puts "Join: #{$!}"
	end
end

puts "Done"
