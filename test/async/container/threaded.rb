# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/threaded"
require "async/container/a_container"

describe Async::Container::Threaded do
	it_behaves_like Async::Container::AContainer
	
	it "is not multiprocess" do
		expect(subject).not.to be(:multiprocess?)
	end
end
