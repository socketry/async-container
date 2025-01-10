# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

on_booted do
	require "async/container/notify"
	
	notify = Async::Container::Notify.open!
	notify&.ready!
end
