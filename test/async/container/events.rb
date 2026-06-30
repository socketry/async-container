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
