#!/usr/bin/env ruby
# frozen_string_literal: true

Process.setproctitle "Preparing for sleep..."

10.times do |i|
	puts "Counting sheep #{i}"
	Process.setproctitle "Counting sheep #{i}"
	
	sleep 10
end

puts "Zzzzzzz"
