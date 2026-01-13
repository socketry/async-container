# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "async"

module Async
	module Container
		AContainer = Sus::Shared("a container") do
			let(:container) {subject.new}
			
			with "#run" do
				it "can run several instances concurrently" do
					container.run do
						sleep(1)
					end
					
					expect(container).to be(:running?)
					
					container.stop(true)
					
					expect(container).not.to be(:running?)
				end
				
				it "can stop an uncooperative child process" do
					container.run do
						while true
							begin
								sleep(1)
							rescue Interrupt
								# Ignore.
							end
						end
					end
					
					expect(container).to be(:running?)
					
					# TODO Investigate why without this, the interrupt can occur before the process is sleeping...
					sleep 0.001
					
					container.stop(true)
					
					expect(container).not.to be(:running?)
				end
			end
			
			with "#async" do
				it "can run concurrently" do
					input, output = IO.pipe
					
					container.async do
						output.write "Hello World"
					end
					
					container.wait
					
					output.close
					expect(input.read).to be == "Hello World"
				end
				
				it "can run concurrently" do
					container.async(name: "Sleepy Jerry") do |task, instance|
						3.times do |i|
							instance.name = "Counting Sheep #{i}"
							
							sleep 0.01
						end
					end
					
					container.wait
				end
			end
			
			it "should be blocking" do
				skip "Fiber.blocking? is not supported!" unless Fiber.respond_to?(:blocking?)
				
				input, output = IO.pipe
				
				container.spawn do
					output.write(Fiber.blocking? != false)
				end
				
				container.wait
				
				output.close
				expect(input.read).to be == "true"
			end
			
			with "instance" do
				it "can generate JSON representation" do
					IO.pipe do |input, output|
						container.spawn do |instance|
							output.write(instance.to_json)
						end
						
						container.wait
						
						expect(container.statistics).to have_attributes(failures: be == 0)
						
						output.close
						instance = JSON.parse(input.read, symbolize_names: true)
						expect(instance).to have_keys(
							process_id: be_a(Integer),
							name: be_a(String),
						)
					end
				end
			end
			
			with "#sleep" do
				it "can sleep for a short time" do
					container.spawn do
						sleep(0.01)
						raise "Boom"
					end
					
					expect(container.statistics).to have_attributes(failures: be == 0)
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be == 1)
				end
			end
			
			with "#stop" do
				it "can gracefully stop the child process" do
					container.spawn do
						sleep(1)
					rescue Interrupt
						# Ignore.
					end
					
					expect(container).to be(:running?)
					
					# See above.
					sleep 0.001
					
					container.stop(true)
					
					expect(container).not.to be(:running?)
				end
				
				it "can forcefully stop the child process" do
					container.spawn do
						sleep(1)
					rescue Interrupt
						# Ignore.
					end
					
					expect(container).to be(:running?)
					
					# See above.
					sleep 0.001
					
					container.stop(false)
					
					expect(container).not.to be(:running?)
				end
				
				it "can stop an uncooperative child process" do
					container.spawn do
						while true
							begin
								sleep(1)
							rescue Interrupt
								# Ignore.
							end
						end
					end
					
					expect(container).to be(:running?)
					
					# See above.
					sleep 0.001
					
					container.stop(true)
					
					expect(container).not.to be(:running?)
				end
			end
			
			with "#ready" do
				it "can notify the ready pipe in an asynchronous context" do
					container.run do |instance|
						Async do
							instance.ready!
						end
					end
					
					expect(container).to be(:running?)
					
					container.wait
					
					container.stop
					
					expect(container).not.to be(:running?)
				end
			end
			
			with "health_check_timeout:" do
				let(:container) {subject.new(health_check_interval: 1.0)}
				
				it "should not terminate a child process if it updates its state within the specified time" do
					# We use #run here to hit the Hybrid container code path:
					container.run(count: 1, health_check_timeout: 1.0) do |instance|
						instance.ready!
						
						10.times do
							instance.ready!
							sleep(0.5)
						end
					end
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be == 0)
				end
				
				it "can terminate a child process if it does not update its state within the specified time" do
					container.spawn(health_check_timeout: 1.0) do |instance|
						instance.ready!
						
						# This should trigger the health check - since restart is false, the process will be terminated:
						sleep
					end
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be > 0)
				end
				
				it "can kill a child process even if it ignores exceptions/signals" do
					# This process never calls ready!, so we need startup_timeout to kill it
					container.spawn(health_check_timeout: 1.0, startup_timeout: 1.0) do |instance|
						while true
							begin
								sleep 1
							rescue Exception => error
								# Ignore.
							end
						end
					end
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be > 0)
				end
			end
			
			with "startup_timeout:" do
				let(:container) {subject.new(health_check_interval: 1.0)}
				
				it "should not terminate a child process if it becomes ready within the startup timeout" do
					container.spawn(startup_timeout: 2.0) do |instance|
						instance.status!("Starting...")
						sleep(0.5)
						
						instance.status!("Preparing...")
						sleep(0.5)
						
						instance.ready!
						
						# Keep running
						sleep(1)
					end
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be == 0)
				end
				
				it "can terminate a child process if it does not become ready within the startup timeout" do
					container.spawn(startup_timeout: 1.0) do |instance|
						instance.status!("Starting...")
						
						# Never call ready! - should be killed by startup timeout
						sleep
					end
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be > 0)
				end
				
				it "can terminate a child process that sends status messages but never becomes ready" do
					container.spawn(startup_timeout: 1.0) do |instance|
						# Send status messages but never become ready
						while true
							instance.status!("Still starting...")
							sleep(0.3)
						end
					end
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be > 0)
				end
				
				it "transitions from startup timeout to health check timeout after becoming ready" do
					container.spawn(startup_timeout: 2.0, health_check_timeout: 1.0) do |instance|
						instance.status!("Starting...")
						sleep(0.5)
						
						instance.ready!
						
						# After becoming ready, health_check_timeout should apply
						# Don't send any more messages - should be killed by health check timeout
						sleep
					end
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be > 0)
				end
				
				it "resets the clock when the child becomes ready" do
					container.spawn(startup_timeout: 1.5, health_check_timeout: 1.0) do |instance|
						instance.status!("Starting...")
						sleep(1.0) # Use up most of startup timeout
						
						instance.ready! # Clock should reset here
						
						# After ready, health_check_timeout applies (1.0 seconds)
						# Send ready! messages periodically to stay alive
						5.times do
							sleep(0.4)
							instance.ready!
						end
					end
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be == 0)
				end
			end
			
			with "broken children" do
				it "can handle children that ignore termination with SIGKILL fallback" do
					# Test behavior that works for both processes (signals) and threads (exceptions)
					container.spawn(restart: false) do |instance|
						instance.ready!
						
						# Ignore termination attempts in a way appropriate to the container type
						if container.class.multiprocess?
							# For multiprocess containers - ignore signals
							Signal.trap(:INT){}
							Signal.trap(:TERM){}
							while true
								sleep(0.1)
							end
						else
							# For threaded containers - ignore exceptions
							while true
								begin
									sleep(0.1)
								rescue Async::Container::Interrupt, Async::Container::Terminate
									# Ignore termination attempts
								end
							end
						end
					end
					
					container.wait_until_ready
					
					# Try to stop with a very short timeout to force escalation
					start_time = Time.now
					container.stop(0.1) # Very short timeout
					end_time = Time.now
					
					# Should stop successfully via SIGKILL/thread termination
					expect(container.size).to be == 0
					
					# Should not hang - escalation should work
					expect(end_time - start_time).to be < 2.0
				end
				
				it "can handle unresponsive children that close pipes but don't exit" do
					container.spawn(restart: false) do |instance|
						instance.ready!
						
						# Close communication pipe to simulate hung process:
						begin
							if instance.respond_to?(:out)
								instance.out.close if instance.out && !instance.out.closed?
							end
						rescue
							# Ignore close errors.
						end
						
						# Become unresponsive:
						if container.class.multiprocess?
							# For multiprocess containers - ignore signals and close file descriptors:
							Signal.trap(:INT){}
							Signal.trap(:TERM){}
							(4..256).each do |fd|
								begin
									IO.for_fd(fd).close
								rescue
									# Ignore errors
								end
							end
							loop {} # Tight loop
						else
							# For threaded containers - just become unresponsive
							loop{} # Tight loop, no exception handling
						end
					end
					
					container.wait_until_ready
					
					# Should not hang even with unresponsive children
					start_time = Time.now
					container.stop(1.0)
					end_time = Time.now
					
					expect(container.size).to be == 0
					# Should complete reasonably quickly via hang prevention
					expect(end_time - start_time).to be < 5.0
				end
			end
		end
	end
end
