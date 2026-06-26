# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Udi Oron.

require "async/container/threaded"
require "async/container/forked"
require "async/container/hybrid"
require "async/container/best"

# Have the worker serialise something about its instance to a pipe, one line per worker.
def report_from_worker(container, **run_options)
	input, output = IO.pipe
	container.run(**run_options) do |instance|
		output.write(yield(instance) + "\n")
	end
	container.wait
	output.close
	input.read.lines.map(&:chomp)
ensure
	input&.close unless input&.closed?
end

describe Async::Container::Threaded do
	it "has no parent" do
		reported = report_from_worker(subject.new, count: 1) do |instance|
			"ordinal=#{instance.ordinal} parent=#{instance.parent.inspect}"
		end
		
		expect(reported).to be == ["ordinal=0 parent=nil"]
	end
end

describe Async::Container::Forked do
	it "has no parent" do
		reported = report_from_worker(subject.new, count: 1) do |instance|
			"ordinal=#{instance.ordinal} parent=#{instance.parent.inspect}"
		end
		
		expect(reported).to be == ["ordinal=0 parent=nil"]
	end
end if Async::Container.fork?

describe Async::Container::Hybrid do
	it "reaches the durable forked ordinal through instance.parent (not the thread ordinal)" do
		reported = report_from_worker(subject.new, count: 2, forks: 2, threads: 1) do |instance|
			"thread=#{instance.ordinal} parent=#{instance.parent&.ordinal}"
		end
		
		# Both workers are thread ordinal 0 within their fork; the durable forked ordinal is on the parent.
		expect(reported.sort).to be == [
			"thread=0 parent=0",
			"thread=0 parent=1",
		]
	end
end if Async::Container.fork?
