# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.

require "async/container/threaded"
require "async/container/a_container"

describe Async::Container::Threaded do
	it_behaves_like Async::Container::AContainer
	
	it "should not be multiprocess" do
		expect(subject).not.to be(:multiprocess?)
	end
end
