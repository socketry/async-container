# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container"

describe Async::Container do
	it "keeps Forked, Threaded, and Hybrid as public factories" do
		expect(Async::Container::Forked.new).to be_a(Async::Container::Generic)
		expect(Async::Container::Threaded.new).to be_a(Async::Container::Generic)
		expect(Async::Container::Hybrid.new).to be_a(Async::Container::Generic)
	end
	
	it "can create the best container" do
		container = Async::Container.new
		
		expect(container).to be_a(Async::Container::Generic)
		
		container.stop(false)
	end
end
