# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "async/container/group"
require "async/container/channel"

describe Async::Container::Group do
	let(:group) {Async::Container::Group.new}
	
	with "#size" do
		it "returns zero for empty group" do
			expect(group.size).to be == 0
		end
		
		it "returns the number of running processes" do
			channel1 = Async::Container::Channel.new
			channel2 = Async::Container::Channel.new
			
			fiber1 = Fiber.new{Fiber.yield}
			fiber2 = Fiber.new{Fiber.yield}
			
			fiber1.resume
			fiber2.resume
			
			group.running[channel1.in] = fiber1
			group.running[channel2.in] = fiber2
			
			expect(group.size).to be == 2
		end
	end
	
	with "#running?" do
		it "returns false for empty group" do
			expect(group).not.to be(:running?)
		end
		
		it "returns true when processes are running" do
			channel = Async::Container::Channel.new
			fiber = Fiber.new{Fiber.yield}
			fiber.resume
			
			group.running[channel.in] = fiber
			
			expect(group).to be(:running?)
		end
	end
	
	with "#any?" do
		it "returns false for empty group" do
			expect(group).not.to be(:any?)
		end
		
		it "returns true when processes are running" do
			channel = Async::Container::Channel.new
			fiber = Fiber.new{Fiber.yield}
			fiber.resume
			
			group.running[channel.in] = fiber
			
			expect(group).to be(:any?)
		end
	end
	
	with "#empty?" do
		it "returns true for empty group" do
			expect(group).to be(:empty?)
		end
		
		it "returns false when processes are running" do
			channel = Async::Container::Channel.new
			fiber = Fiber.new{Fiber.yield}
			fiber.resume
			
			group.running[channel.in] = fiber
			
			expect(group).not.to be(:empty?)
		end
	end
	
	with "#inspect" do
		it "provides human-readable representation" do
			expect(group.inspect).to be =~ /Async::Container::Group/
			expect(group.inspect).to be =~ /running=0/
		end
		
		it "shows the number of running processes" do
			channel = Async::Container::Channel.new
			fiber = Fiber.new{Fiber.yield}
			fiber.resume
			
			group.running[channel.in] = fiber
			
			expect(group.inspect).to be =~ /running=1/
		end
	end
	
	with "#health_check!" do
		it "resumes all fibers with :health_check! message" do
			messages = []
			
			2.times do
				channel = Async::Container::Channel.new
				fiber = Fiber.new do
					result = Fiber.yield
					messages << result
				end
				
				fiber.resume
				group.running[channel.in] = fiber
			end
			
			group.health_check!
			
			expect(messages).to be == [:health_check!, :health_check!]
		end
		
		it "does nothing for empty group" do
			expect do
				group.health_check!
			end.not.to raise_exception
		end
	end
	
	with "#interrupt" do
		it "resumes all fibers with Interrupt" do
			messages = []
			
			2.times do
				channel = Async::Container::Channel.new
				fiber = Fiber.new do
					result = Fiber.yield
					messages << result
				end
				
				fiber.resume
				group.running[channel.in] = fiber
			end
			
			group.interrupt
			
			expect(messages).to be == [Async::Container::Interrupt, Async::Container::Interrupt]
		end
	end
	
	with "#terminate" do
		it "resumes all fibers with Terminate" do
			messages = []
			
			2.times do
				channel = Async::Container::Channel.new
				fiber = Fiber.new do
					result = Fiber.yield
					messages << result
				end
				
				fiber.resume
				group.running[channel.in] = fiber
			end
			
			group.terminate
			
			expect(messages).to be == [Async::Container::Terminate, Async::Container::Terminate]
		end
	end
	
	with "#kill" do
		it "resumes all fibers with Kill" do
			messages = []
			
			2.times do
				channel = Async::Container::Channel.new
				fiber = Fiber.new do
					result = Fiber.yield
					messages << result
				end
				
				fiber.resume
				group.running[channel.in] = fiber
			end
			
			group.kill
			
			expect(messages).to be == [Async::Container::Kill, Async::Container::Kill]
		end
	end
	
	# Regression test for a bug where restarting a child during health check caused
	# "RuntimeError: can't add a new key into hash during iteration"
	# 
	# The scenario:
	# - A container spawns children with `restart: true` and `health_check_timeout: N`
	# - health_check! calls @running.each_value { |fiber| fiber.resume(:health_check!) }
	# - A resumed fiber detects health check failure and kills the child
	# - The spawn fiber's while loop continues (restart: true) and calls wait_for with a new child
	# - wait_for tries to add to @running while health_check! is still iterating
	# - This used to cause: RuntimeError: can't add a new key into hash during iteration
	it "can restart child during health_check! iteration without error" do
		channel1 = Async::Container::Channel.new
		channel2 = Async::Container::Channel.new
		
		# Simulate the spawn fiber that restarts on health check failure
		restart = true
		fiber = Fiber.new do
			while restart
				result = Fiber.yield # Wait to be resumed
				
				if result == :health_check!
					# Health check failed! Simulate the restart logic:
					# The wait_for will return (simulated by breaking from this iteration)
					# and the while loop continues, creating a new child
					
					# Simulate: child.kill! happens, wait_for returns
					# Now the while loop continues and calls wait_for with new child
					Fiber.new do
						group.wait_for(channel2) do |msg|
							# New child waiting
						end
					end.resume
					
					restart = false # Only do this once for the test
				end
			end
		end
		
		# Start the fiber and add it to @running (simulating first wait_for call)
		fiber.resume
		group.running[channel1.in] = fiber
		
		# The fix ensures this doesn't raise RuntimeError during iteration
		expect do
			group.health_check!
		end.not.to raise_exception
	end
	
	# Regression test with multiple children where one restarts during health check
	it "can handle one of multiple children restarting during health check" do
		# Create two children, both with restart capability
		2.times do |i|
			channel = Async::Container::Channel.new
			
			fiber = Fiber.new do
				iteration = 0
				loop do
					iteration += 1
					result = Fiber.yield
					
					# First child fails health check on first iteration
					if i == 0 && iteration == 1 && result == :health_check!
						# Simulate health check failure and restart:
						# Kill the old child, create new one
						new_channel = Async::Container::Channel.new
						
						# This mimics what happens in spawn's while @running loop
						# after wait_for returns due to child being killed
						group.wait_for(new_channel) do |msg|
							# New child process
						end
						
						break # Exit this child's loop
					end
				end
			end
			
			fiber.resume
			group.running[channel.in] = fiber
		end
		
		# The fix ensures this doesn't raise RuntimeError when the first fiber restarts
		expect do
			group.health_check!
		end.not.to raise_exception
	end

	it "handles nil fiber in @running during iteration (re-entrance scenario)" do
		# This test simulates a scenario where:
		# 1. IO.select returns [io1, io2]
		# 2. While resuming fiber for io1, a re-entrant call completes fiber for io2
		# 3. When iteration continues to io2, @running[io2] is nil
		# Without defensive check (&.), this would crash with NoMethodError
		
		channel1 = Async::Container::Channel.new
		channel2 = Async::Container::Channel.new
		
		fiber1 = Fiber.new{group.running.delete(channel2.in)}
		fiber2 = Fiber.new{Fiber.yield}
		
		fiber2.resume
		
		group.running[channel1.in] = fiber1
		group.running[channel2.in] = fiber2
		
		# Mock select to return both channels:
		expect(group).to receive(:select).and_return([channel1.in, channel2.in])
		
		# This should not crash due to &. operator:
		group.sleep(0)
		
		# Verify fiber2 was removed
		expect(group.running.key?(channel2.in)).to be == false
	end
end
