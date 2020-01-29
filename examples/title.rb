#!/usr/bin/env ruby

Process.setproctitle "Preparing for sleep..."

10.times do |i|
	puts "Counting sheep #{i}"
	Process.setproctitle "Counting sheep #{i}"
	
	sleep 10
end

puts "Zzzzzzz"
