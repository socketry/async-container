# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2024, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "async/container/forked"
require "async/container/a_container"

describe Async::Container::Forked do
	let(:container) {subject.new}
	
	it_behaves_like Async::Container::AContainer
	
	it "can restart child" do
		trigger = IO.pipe
		pids = IO.pipe
		
		thread = Thread.new do
			container.async(restart: true) do
				trigger.first.gets
				pids.last.puts Process.pid.to_s
			end
			
			container.wait
		end
		
		3.times do
			trigger.last.puts "die"
			_child_pid = pids.first.gets
		end
		
		thread.kill
		thread.join
		
		expect(container.statistics.spawns).to be == 1
		expect(container.statistics.restarts).to be == 2
	end
	
	it "can handle interrupts" do
		finished = IO.pipe
		interrupted = IO.pipe
		
		container.spawn(restart: true) do |instance|
			Thread.handle_interrupt(Interrupt => :never) do
				instance.ready!
				
				finished.first.gets
			rescue ::Interrupt
				interrupted.last.puts "incorrectly interrupted"
			end
		rescue ::Interrupt
			interrupted.last.puts "correctly interrupted"
		end
		
		container.wait_until_ready
		
		container.group.interrupt
		sleep(0.001)
		finished.last.puts "finished"
		
		expect(interrupted.first.gets).to be == "correctly interrupted\n"
		
		container.stop
	end
	
	it "should be multiprocess" do
		expect(subject).to be(:multiprocess?)
	end
end if Async::Container.fork?
