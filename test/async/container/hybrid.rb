# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/hybrid"
require "async/container/a_container"
require "sus/fixtures/async/scheduler_context"

describe Async::Container::Hybrid do
	include Sus::Fixtures::Async::SchedulerContext
	
	it_behaves_like Async::Container::AContainer
	
	it "is a hybrid container" do
		container = subject.new
		
		expect(container).to be_a(subject)
		
		container.stop(false)
	end
	
	it "is multiprocess" do
		expect(subject).to be(:multiprocess?)
	end
end if ::Process.respond_to?(:fork) && ::Process.respond_to?(:setpgid)
