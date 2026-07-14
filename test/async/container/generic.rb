# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/generic"
require "async/container/threaded/child"
require "sus/fixtures/async/scheduler_context"

describe Async::Container::Generic do
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:container) {subject.new(Async::Container::Threaded::Child)}
	
	class RecordingPolicy < Async::Container::Policy
		def initialize
			@events = []
		end
		
		attr :events
		
		def startup_failed(container, child, age:, timeout:, **options)
			@events << [:startup_failed, age, timeout]
			
			super
		end
		
		def health_check_failed(container, child, age:, timeout:, **options)
			@events << [:health_check_failed, age, timeout]
			
			super
		end
	end
	
	it "spawns children and waits until they are ready" do
		container.spawn do |instance|
			instance.ready!(status: "ready")
			sleep
		end
		
		expect(container.wait_until_ready).to be == true
		expect(container.size).to be == 1
		expect(container.group.children.all?(&:ready?)).to be == true
		
		container.stop(false)
		
		expect(container).not.to be(:running?)
		expect(container.statistics).to have_attributes(spawns: be == 1, failures: be == 0)
	end
	
	it "records child failures" do
		container.spawn do
			raise "boom"
		end
		
		container.wait
		
		expect(container).not.to be(:running?)
		expect(container.statistics).to have_attributes(spawns: be == 1, failures: be == 1)
		expect(container).to be(:failed?)
	end
	
	it "does not block waiting for readiness after a child fails to start" do
		container.spawn do
			raise "boom"
		end
		
		expect(container.wait_until_ready).to be == false
		expect(container).not.to be(:running?)
	end
	
	it "restarts children when requested" do
		count = 0
		
		container.spawn(restart: true) do |instance|
			count += 1
			raise "boom" if count == 1
			
			instance.ready!
			sleep
		end
		
		container.wait_until_ready
		container.stop(false)
		
		expect(container.statistics).to have_attributes(spawns: be == 2, restarts: be == 1, failures: be == 1)
	end
	
	it "does not restart children while stopping" do
		container.spawn(restart: true) do |instance|
			instance.ready!
			sleep
		rescue Interrupt
			# Graceful shutdown.
		end
		
		expect(container.wait_until_ready).to be == true
		
		container.stop(true)
		
		expect(container.statistics).to have_attributes(spawns: be == 1, restarts: be == 0)
	end
	
	it "supports keyed children" do
		expect(container.spawn(key: :worker) do |instance|
			instance.ready!
			sleep
		end).to be == true
		
		expect(container.wait_until_ready).to be == true
		expect(container.spawn(key: :worker){sleep}).to be == false
		expect(container[:worker]).not.to be_nil
		
		container.stop(false)
	end
	
	it "fails startup when the child sends status messages but never becomes ready" do
		policy = RecordingPolicy.new
		container = subject.new(Async::Container::Threaded::Child, policy: policy)
		
		container.spawn(startup_timeout: 0.05) do |instance|
			loop do
				instance.status!("Still starting...")
				sleep 0.01
			end
		end
		
		container.wait
		
		expect(container).not.to be(:running?)
		expect(container).to be(:failed?)
		expect(container.statistics.failures).to be == 1
		expect(policy.events).to have_attributes(size: be == 1)
		
		event, age, timeout = policy.events.first
		expect(event).to be == :startup_failed
		expect(age).to be >= timeout
		expect(timeout).to be == 0.05
	end
	
	it "does not fail startup if the child becomes ready before the startup timeout" do
		policy = RecordingPolicy.new
		container = subject.new(Async::Container::Threaded::Child, policy: policy)
		
		container.spawn(startup_timeout: 1.0) do |instance|
			instance.status!("Starting...")
			sleep 0.01
			instance.ready!
		end
		
		container.wait
		
		expect(container).not.to be(:running?)
		expect(container).not.to be(:failed?)
		expect(container.statistics.failures).to be == 0
		expect(policy.events).to be(:empty?)
	end
end

describe Async::Container::Generic do
	let(:container) {subject.new(Async::Container::Threaded::Child)}
	
	with "without an async task" do
		it "spawns children using an internal lifecycle task" do
			container.spawn do |instance|
				instance.ready!
				sleep
			end
			
			expect(container.wait_until_ready).to be == true
			
			container.stop(false)
			
			expect(container).not.to be(:running?)
		end
		
		it "runs lifecycle blocks in an internal scheduler" do
			ready = Thread::Queue.new
			finish = Thread::Queue.new
			
			thread = subject::LifecycleThread.new do |task|
				ready.push(Async::Task.current?)
				finish.pop
			end
			
			expect(ready.pop).to be_a(Async::Task)
			expect(thread.status).to be == :running
			
			finish.push(true)
			thread.wait
			
			expect(thread.status).not.to be == :running
		end
	end
end
