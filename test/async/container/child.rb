# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/child"

describe Async::Container::Child do
	class TestChild < Async::Container::Child
		def initialize(channel)
			super(channel)
			
			@reap_results = []
			@killed = false
		end
		
		attr :reap_results
		
		def kill!
			@killed = true
		end
		
		def killed?
			@killed
		end
		
		def reap(timeout = nil)
			@reap_results << timeout
			
			if timeout
				nil
			else
				:status
			end
		end
	end
	
	it "kills and reaps indefinitely if the channel closes but bounded reaping times out" do
		channel = Async::Container::Channel.new
		child = TestChild.new(channel)
		
		channel.close_write
		
		status = child.wait(0.001)
		
		expect(status).to be == :status
		expect(child).to be(:killed?)
		expect(child.reap_results.size).to be == 2
		expect(child.reap_results.first).to be <= Async::Container::Child::REAP_TIMEOUT
		expect(child.reap_results.last).to be_nil
	end
	
	it "uses the default reap timeout when wait has no timeout" do
		channel = Async::Container::Channel.new
		child = TestChild.new(channel)
		
		channel.close_write
		
		status = child.wait
		
		expect(status).to be == :status
		expect(child.reap_results.first).to be == Async::Container::Child::REAP_TIMEOUT
	end
end
