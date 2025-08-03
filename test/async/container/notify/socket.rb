# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/notify/socket"

describe Async::Container::Notify::Socket do
	with ".open!" do
		it "can open a socket" do
			socket = subject.open!({subject::NOTIFY_SOCKET => "test"})
			
			expect(socket).to have_attributes(path: be == "test")
		end
	end
end
