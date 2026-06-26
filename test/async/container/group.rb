# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "async/container/group"

describe Async::Container::Group do
	let(:group) {Async::Container::Group.new}
	
	class FakeChild
		def initialize
			@events = []
		end
		
		attr :events
		
		def interrupt!
			@events << :interrupt
		end
		
		def terminate!
			@events << :terminate
		end
		
		def kill!
			@events << :kill
		end
	end
	
	with "#size" do
		it "returns zero for empty group" do
			expect(group.size).to be == 0
		end
		
		it "returns the number of registered children" do
			child1 = FakeChild.new
			child2 = FakeChild.new
			
			group.insert(child1)
			group.insert(child2)
			
			expect(group.size).to be == 2
		end
	end
	
	with "#running?" do
		it "returns false for empty group" do
			expect(group).not.to be(:running?)
		end
		
		it "returns true while a supervisor is running" do
			queue = Thread::Queue.new
			release = Thread::Queue.new
			
			group.supervise do
				queue << :running
				release.pop
			end
			
			expect(queue.pop).to be == :running
			expect(group).to be(:running?)
			
			release << true
			group.wait
		end
	end
	
	with "#empty?" do
		it "returns true for empty group" do
			expect(group).to be(:empty?)
		end
	end
	
	with "#inspect" do
		it "provides human-readable representation" do
			expect(group.inspect).to be =~ /Async::Container::Group/
			expect(group.inspect).to be =~ /running=0/
		end
		
		it "shows the number of registered children" do
			child = FakeChild.new
			group.insert(child)
			
			expect(group.inspect).to be =~ /running=1/
		end
	end
	
	with "bulk child control" do
		it "interrupts all registered children" do
			child1 = FakeChild.new
			child2 = FakeChild.new
			
			group.insert(child1)
			group.insert(child2)
			group.interrupt
			
			expect(child1.events).to be == [:interrupt]
			expect(child2.events).to be == [:interrupt]
		end
		
		it "terminates all registered children" do
			child = FakeChild.new
			
			group.insert(child)
			group.terminate
			
			expect(child.events).to be == [:terminate]
		end
		
		it "kills all registered children" do
			child = FakeChild.new
			
			group.insert(child)
			group.kill
			
			expect(child.events).to be == [:kill]
		end
	end
	
	with "#sleep" do
		it "wakes when child state changes" do
			thread = Thread.new do
				group.sleep
				:woken
			end
			
			group.health_check!
			
			expect(thread.value).to be == :woken
		end
	end
	
	with "#wait" do
		it "waits until all supervisors finish" do
			group.supervise do
				sleep(0.01)
			end
			
			group.wait
			
			expect(group).not.to be(:running?)
		end
	end
end
