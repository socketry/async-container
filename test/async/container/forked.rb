# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "async/container/best"
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
		
	it "can handle children that ignore SIGTERM with SIGKILL fallback" do
		# Create a child that ignores SIGINT and SIGTERM
		container.spawn(restart: false) do |instance|
			# Trap both SIGINT and SIGTERM to ignore them (like the example)
			Signal.trap(:INT) {}
			Signal.trap(:TERM) {}
				
			instance.ready!
				
			# Infinite loop that can only be stopped by SIGKILL
			while true
				sleep(0.1)
			end
		end
			
		container.wait_until_ready
			
		# Try to stop with a very short timeout
		# This should first try SIGINT, then SIGTERM, then fall back to SIGKILL
		start_time = Time.now
		container.stop(0.1) # 100ms timeout - very short
		end_time = Time.now
			
		# The container should stop successfully even though the child ignored signals
		expect(container.size).to be == 0
			
		# It should not take too long (should not hang waiting for SIGTERM)
		# Allow some buffer time for the SIGKILL fallback mechanism
		expect(end_time - start_time).to be < 2.0
	end
		
	it "can handle unresponsive children that close pipes but don't exit" do
		# Simulate a production hang scenario where a child closes file descriptors
		# but doesn't actually exit, becoming unresponsive
		container.spawn(restart: false) do |instance|
			# Ignore all signals
			Signal.trap(:INT) {}
			Signal.trap(:TERM) {}
				
			instance.ready!
				
			# Close all file descriptors above 3 (like the production hang scenario)
			# This will close the notify pipe, making the parent think we've "exited"
			(4..256).each do |fd|
				begin
					IO.for_fd(fd).close
				rescue
					# Ignore errors for non-existent file descriptors
				end
			end
				
			# Now become unresponsive (infinite loop without yielding)
			while true
				# Tight loop without sleep - process is unresponsive but still alive
			end
		end
			
		container.wait_until_ready
			
		# This should not hang - even with unresponsive processes, stop should work
		start_time = Time.now
		container.stop(2.0) # Give it a reasonable timeout for testing
		end_time = Time.now
			
		# Container should stop successfully
		expect(container.size).to be == 0
			
		# Should complete within the child's individual timeout + buffer (30s + 5s)
		# The process is so unresponsive it needs the individual Child timeout to kill it
		# This proves the hang prevention works - without it, this would hang forever
		expect(end_time - start_time).to be < 35.0
	end
end if Async::Container.fork?
