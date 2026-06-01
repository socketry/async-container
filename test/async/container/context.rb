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
	it "exposes a single :thread frame and no parent via instance.context" do
		reported = report_from_worker(subject.new, count: 1) do |instance|
			"#{instance.context.map {|f| "#{f.kind}:#{f.num}"}.join(",")}|parent=#{instance.parent.inspect}"
		end

		expect(reported).to be == ["thread:0|parent=nil"]
	end
end

describe Async::Container::Forked do
	it "exposes a single :process frame and no parent via instance.context" do
		reported = report_from_worker(subject.new, count: 1) do |instance|
			"#{instance.context.map {|f| "#{f.kind}:#{f.num}"}.join(",")}|parent=#{instance.parent.inspect}"
		end

		expect(reported).to be == ["process:0|parent=nil"]
	end
end if Async::Container.fork?

describe Async::Container::Hybrid do
	it "exposes [:process, :thread] frames via instance.context" do
		reported = report_from_worker(subject.new, count: 1, forks: 1, threads: 1) do |instance|
			instance.context.map {|f| f.kind}.join(",")
		end

		expect(reported).to be == ["process,thread"]
	end

	it "reaches the durable forked num through instance.parent (not the thread num)" do
		reported = report_from_worker(subject.new, count: 2, forks: 2, threads: 1) do |instance|
			"#{instance.kind}/#{instance.num} parent=#{instance.parent&.kind}/#{instance.parent&.num}"
		end

		# Both workers are thread num 0 within their fork; the durable forked num is on the parent.
		expect(reported.sort).to be == [
			"thread/0 parent=process/0",
			"thread/0 parent=process/1",
		]
	end
end if Async::Container.fork?
