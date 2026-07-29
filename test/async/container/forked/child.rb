# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/forked/child"
require "async/container/a_child"

describe Async::Container::Forked::Child do
	it_behaves_like Async::Container::AChild
	
	it "returns a process status when killed" do
		ready = ::IO.pipe
		
		child = subject.call(name: "test-child") do
			ready.last.puts "ready"
			sleep
		end
		
		ready.first.gets
		
		status = child.stop(false)
		
		expect(status).to be_a(::Process::Status)
		expect(status.termsig).to be == Signal.list["KILL"]
	end
	
	it "returns a failed process status when the child raises an exception" do
		child = subject.call(name: "test-child") do
			raise "boom"
		end
		
		status = child.wait
		
		expect(status).to be_a(::Process::Status)
		expect(status.exitstatus).to be == 1
	end
end if ::Process.respond_to?(:fork) && ::Process.respond_to?(:setpgid)
