#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require 'async/container'

container = Async::Container.new
input, output = IO.pipe

container.async do |instance|
	output.close
	
	while message = input.gets
		puts "Hello World from #{instance}: #{message}"
	end
	
	puts "exiting"
end

5.times do |i|
	output.puts "#{i}"
end

output.close

container.wait
