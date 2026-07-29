# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "async/container/best"
require "async/container/forked"
require "async/container/a_container"
require "sus/fixtures/async/scheduler_context"
require "weakref"

describe Async::Container::Forked do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:container) {subject.new}
	
	def fork_with_weak_marker(weak_marker, output)
		Async::Container::Forked::Child.fork do
			3.times do
				GC.start(full_mark: true, immediate_sweep: true)
			end
				
			output.puts(weak_marker.weakref_alive? ? "alive" : "collected")
		ensure
			output.close
		end
	end
		
	it_behaves_like Async::Container::AContainer
		
	it "forks with a clean child fiber stack" do
		input, output = IO.pipe
		marker = Object.new
		weak_marker = WeakRef.new(marker)
			
		child = fork_with_weak_marker(weak_marker, output)
		output.close
			
		expect(input.read).to be == "collected\n"
		expect(child.wait).to be(:success?)
			
		# Keep the marker live on the caller's stack until after the child exits:
		marker.object_id
	ensure
		input&.close
		output&.close
		child&.wait
	end
		
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
