# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

# gem install async-container
gem "async-container"

require 'async/clock'
require_relative '../../lib/async/container'

def fibonacci(n)
	if n < 2
		return n
	else
		return fibonacci(n-1) + fibonacci(n-2)
	end
end

require 'sqlite3'

def work(*)
	512.times do
		File.read("/dev/zero", 1024*1024).bytesize
	end
end

def measure_work(container, **options, &block)
	duration = Async::Clock.measure do
		container.run(**options, &block)
		container.wait
	end
	
	puts "Duration for #{container.class}: #{duration}"
end

threaded = Async::Container::Threaded.new
measure_work(threaded, count: 32, &self.method(:work))

forked = Async::Container::Forked.new
measure_work(forked, count: 32, &self.method(:work))

hybrid = Async::Container::Hybrid.new
measure_work(hybrid, count: 32, &self.method(:work))
