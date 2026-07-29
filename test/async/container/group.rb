# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.

require "async"
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
		
		def restart!
			@events << :restart
		end
	end
	
	it "tracks children and emits add/remove events" do
		child = FakeChild.new
		
		Sync do
			group.add(child)
			
			expect(group.children).to be(:include?, child)
			expect(group.running).to be == group.children
			expect(group.size).to be == 1
			expect(group).to be(:running?)
			
			spawn = group.wait
			expect(spawn).to be_a(Async::Container::Group::Spawn)
			expect(spawn.child).to be == child
			
			group.remove(child, :status)
			
			exit = group.wait
			expect(exit).to be_a(Async::Container::Group::Exit)
			expect(exit.child).to be == child
			expect(exit.status).to be == :status
			
			expect(group).to be(:empty?)
		end
	end
	
	it "rejects duplicate children" do
		child = FakeChild.new
		
		Sync do
			group.add(child)
			
			expect do
				group.add(child)
			end.to raise_exception(ArgumentError)
		end
	end
	
	it "rejects removing missing children" do
		child = FakeChild.new
		
		expect do
			group.remove(child)
		end.to raise_exception(ArgumentError)
	end
	
	it "emits update events without mutating child state" do
		child = FakeChild.new
		message = {ready: true}
		
		Sync do
			group.add(child)
			group.wait
			
			group.update(child, message)
			
			update = group.wait
			expect(update).to be_a(Async::Container::Group::Update)
			expect(update.child).to be == child
			expect(update.message).to be == message
		end
	end
	
	it "waits until the group is empty" do
		child = FakeChild.new
		
		Sync do |task|
			group.add(child)
			group.wait
			
			task.async do
				group.remove(child)
			end
			
			expect(group.wait_until_empty).to be == true
		end
	end
	
	it "sends interrupts before killing during bounded graceful stop" do
		child = FakeChild.new
		
		Sync do |task|
			group.add(child)
			group.wait
			
			task.async do
				sleep 0.01
				group.remove(child)
			end
			
			result = group.stop(0.001)
			
			expect(result).to be == true
			expect(child.events).to be == [:interrupt, :kill]
		end
	end
	
	it "can stop gracefully when children are removed" do
		child = FakeChild.new
		
		Sync do |task|
			group.add(child)
			group.wait
			
			task.async do
				sleep 0.001
				group.remove(child)
			end
			
			expect(group.stop(true)).to be == true
			expect(child.events).to be == [:interrupt]
		end
	end
	
	it "kills immediately when graceful is false" do
		child = FakeChild.new
		
		Sync do |task|
			group.add(child)
			group.wait
			
			task.async do
				sleep 0.001
				group.remove(child)
			end
			
			expect(group.stop(false)).to be == true
			expect(child.events).to be == [:kill]
		end
	end
end
