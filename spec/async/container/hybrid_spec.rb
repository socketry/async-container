# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2020, by Samuel Williams.

require 'async/container/hybrid'
require 'async/container/best'

require_relative 'shared_examples'

RSpec.describe Async::Container::Hybrid, if: Async::Container.fork? do
	subject {described_class.new}
	
	it_behaves_like Async::Container
	
	it "should be multiprocess" do
		expect(described_class).to be_multiprocess
	end
end
