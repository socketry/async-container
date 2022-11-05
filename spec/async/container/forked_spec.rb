# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2020, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "async/container"
require "async/container/forked"

require_relative 'shared_examples'

RSpec.describe Async::Container::Forked, if: Async::Container.fork? do
	subject {described_class.new}
	
	it_behaves_like Async::Container
	
	it "can restart child" do
		trigger = IO.pipe
		pids = IO.pipe
		
		thread = Thread.new do
			subject.async(restart: true) do
				trigger.first.gets
				pids.last.puts Process.pid.to_s
			end
			
			subject.wait
		end
		
		3.times do
			trigger.last.puts "die"
			_child_pid = pids.first.gets
		end
		
		thread.kill
		thread.join
		
		expect(subject.statistics.spawns).to be == 1
		expect(subject.statistics.restarts).to be == 2
	end
	
	it "should be multiprocess" do
		expect(described_class).to be_multiprocess
	end
end
