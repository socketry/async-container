# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/controller"

describe Async::Container::Controller::SignalEvent do
	it "calls the handler" do
		applied = false
		
		event = subject.new(:USR1, proc{applied = true})
		
		expect(event.signal).to be == :USR1
		
		event.call
		
		expect(applied).to be == true
	end
end

describe Async::Container::Events do
	let(:events) {subject.new}
	
	it "wakes IO.select when an event is queued" do
		event = Object.new
		
		events << event
		
		readable, _, _ = IO.select([events.io], nil, nil, 0)
		
		expect(readable).to be == [events.io]
		expect(events.pop(timeout: 0)).to be == event
	end
	
	it "returns nil when no event is queued" do
		expect(events.pop(timeout: 0)).to be_nil
	end
end
