# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "async/container/policy"
require "async/container/best"

describe Async::Container::Policy do
	let(:policy) {subject.new}
	
	with "interface" do
		it "has child_spawn callback" do
			expect(policy).to respond_to(:child_spawn)
		end
		
		it "has child_exit callback" do
			expect(policy).to respond_to(:child_exit)
		end
		
		it "has health_check_failed callback" do
			expect(policy).to respond_to(:health_check_failed)
		end
		
		it "has startup_failed callback" do
			expect(policy).to respond_to(:startup_failed)
		end
	end
	
	with "helper methods" do
		let(:mock_status) do
			Class.new do
				attr_accessor :termsig, :exitstatus
				
				def success?
					exitstatus == 0
				end
			end
		end
		
		it "can detect segfault" do
			status = mock_status.new
			status.termsig = Signal.list["SEGV"]
			
			expect(policy).to be(:segfault?, status)
		end
		
		it "can detect non-segfault" do
			status = mock_status.new
			status.exitstatus = 1
			
			expect(policy).not.to be(:segfault?, status)
		end
		
		it "can detect abort" do
			status = mock_status.new
			status.termsig = Signal.list["ABRT"]
			
			expect(policy).to be(:abort?, status)
		end
		
		it "can detect killed" do
			status = mock_status.new
			status.termsig = Signal.list["KILL"]
			
			expect(policy).to be(:killed?, status)
		end
		
		it "can detect success" do
			status = mock_status.new
			status.exitstatus = 0
			
			expect(policy).to be(:success?, status)
		end
		
		it "can detect failure" do
			status = mock_status.new
			status.exitstatus = 1
			
			expect(policy).not.to be(:success?, status)
		end
		
		it "can get signal number" do
			status = mock_status.new
			status.termsig = 9
			
			expect(policy.signal(status)).to be == 9
		end
		
		it "can get exit code" do
			status = mock_status.new
			status.exitstatus = 42
			
			expect(policy.exit_code(status)).to be == 42
		end
	end
	
	with "custom policy" do
		let(:events) {[]}
		let(:mock_status) do
			Class.new do
				attr_accessor :termsig, :exitstatus
				
				def success?
					exitstatus == 0
				end
			end
		end
		
		let(:tracking_policy) do
			Class.new(Async::Container::Policy) do
				def initialize(events)
					@events = events
				end
				
				def child_spawn(container, child, name:, key:)
					@events << [:spawn, name, key]
				end
				
				def child_exit(container, child, status:, name:, key:)
					@events << [:exit, name, success?(status)]
				end
			end.new(events)
		end
		
		it "can track child_spawn" do
			tracking_policy.child_spawn(nil, nil, name: "worker", key: :test)
			
			expect(events.size).to be == 1
			expect(events.first).to be == [:spawn, "worker", :test]
		end
		
		it "can track child_exit" do
			status = mock_status.new
			status.exitstatus = 0
			
			tracking_policy.child_exit(nil, nil, status: status, name: "worker", key: nil)
			
			expect(events.size).to be == 1
			expect(events.first).to be == [:exit, "worker", true]
		end
	end
	
	with "default behavior" do
		let(:mock_child) do
			Class.new do
				attr_reader :killed
				
				def initialize
					@killed = false
				end
				
				def kill!
					@killed = true
				end
			end
		end
		
		it "kills child on health_check_failed" do
			child = mock_child.new
			
			policy.health_check_failed(nil, child, age: 10, timeout: 5)
			
			expect(child.killed).to be == true
		end
		
		it "kills child on startup_failed" do
			child = mock_child.new
			
			policy.startup_failed(nil, child, age: 10, timeout: 5)
			
			expect(child.killed).to be == true
		end
	end
	
	with "container integration" do
		let(:spawns) {[]}
		let(:exits) {[]}
		
		let(:tracking_policy) do
			Class.new(Async::Container::Policy) do
				def initialize(spawns, exits)
					@spawns = spawns
					@exits = exits
				end
				
				def child_spawn(container, child, name:, key:)
					@spawns << {name: name, key: key}
				end
				
				def child_exit(container, child, status:, name:, key:)
					@exits << {name: name, success: success?(status)}
				end
			end.new(spawns, exits)
		end
		
		it "invokes callbacks in real container" do
			container = Async::Container.best_container_class.new(policy: tracking_policy)
			
			container.spawn(name: "test-worker") do |instance|
				instance.ready!
			end
			
			container.wait
			
			expect(spawns.size).to be == 1
			expect(spawns.first).to have_keys(name: be == "test-worker", key: be_nil)
			
			expect(exits.size).to be == 1
			expect(exits.first).to have_keys(name: be == "test-worker", success: be_truthy)
		end
		
		it "tracks failures correctly" do
			container = Async::Container.best_container_class.new(policy: tracking_policy)
			
			container.spawn(name: "failing-worker") do |instance|
				instance.ready!
				exit(1)
			end
			
			container.wait
			
			expect(exits.size).to be == 1
			expect(exits.first).to have_keys(name: be == "failing-worker", success: be_falsey)
			expect(container.statistics.failures).to be == 1
		end
		
		it "invokes callbacks for multiple children" do
			container = Async::Container.best_container_class.new(policy: tracking_policy)
			
			3.times do |i|
				container.spawn(name: "worker-#{i}") do |instance|
					instance.ready!
				end
			end
			
			container.wait
			
			expect(spawns.size).to be == 3
			expect(exits.size).to be == 3
			exits.each do |exit|
				expect(exit).to have_keys(success: be_truthy)
			end
		end
	end
end
