# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/generic"
require "async/container/threaded/child"

describe Async::Container::Generic do
	let(:container) {subject.new(Async::Container::Threaded::Child)}
	
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
	
	it "supports keyed children" do
		expect(container.spawn(key: :worker) do |instance|
			instance.ready!
			sleep
		end).to be == true
		
		expect(container.wait_until_ready).to be == true
		expect(container.spawn(key: :worker) {sleep}).to be == false
		expect(container[:worker]).not.to be_nil
		
		container.stop(false)
	end
end
