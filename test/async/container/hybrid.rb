# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require 'async/container/hybrid'
require 'async/container/best'

require 'a_container'

describe Async::Container::Hybrid do
	it_behaves_like AContainer
	
	it "should be multiprocess" do
		expect(subject).to be(:multiprocess?)
	end
end if Async::Container.fork?
