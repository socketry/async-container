# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/forked"
require "async/container/a_container"

describe Async::Container::Forked do
	it_behaves_like Async::Container::AContainer
	
	it "is multiprocess" do
		expect(subject).to be(:multiprocess?)
	end
end if ::Process.respond_to?(:fork) && ::Process.respond_to?(:setpgid)
