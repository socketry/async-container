# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/threaded/child"
require "async/container/a_child"

describe Async::Container::Threaded::Child do
	it_behaves_like Async::Container::AChild
	
	it "returns the exception as the failure status error" do
		child = subject.call(name: "test-child") do
			raise "boom"
		end
		
		status = child.wait
		
		expect(status).not.to be(:success?)
		expect(status.error).to be_a(RuntimeError)
	end
	
	it "returns killed as the immediate stop status error" do
		ready = ::Thread::Queue.new
		
		child = subject.call(name: "test-child") do
			ready.push(true)
			sleep
		end
		
		ready.pop
		
		status = child.stop(false)
		
		expect(status).not.to be(:success?)
		expect(status.error).to be == :killed
	end
	
	it "serializes status values" do
		success = subject::Status.new
		failure = subject::Status.new(:killed)
		
		expect(success.as_json).to be == true
		expect(failure.as_json).to be == ":killed"
		expect(success.to_s).to be == "#<Async::Container::Threaded::Child::Status success>"
		expect(failure.to_s).to be == "#<Async::Container::Threaded::Child::Status failure>"
	end
end
