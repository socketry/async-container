# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2020, by Samuel Williams.

require "async/container/threaded"

require_relative 'shared_examples'

RSpec.describe Async::Container::Threaded do
	subject {described_class.new}
	
	it_behaves_like Async::Container
	
	it "should not be multiprocess" do
		expect(described_class).to_not be_multiprocess
	end
end
