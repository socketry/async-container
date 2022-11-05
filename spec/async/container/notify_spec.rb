# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

require "async/container/controller"
require "async/container/notify/server"

RSpec.describe Async::Container::Notify, if: Async::Container.fork? do
	let(:server) {described_class::Server.open}
	let(:notify_socket) {server.path}
	let(:client) {described_class::Socket.new(notify_socket)}
	
	describe '#ready!' do
		it "should send message" do
			begin
				context = server.bind
				
				pid = fork do
					client.ready!
				end
				
				messages = []
				
				Sync do
					context.receive do |message, address|
						messages << message
						break
					end
				end
				
				expect(messages.last).to include(ready: true)
			ensure
				context&.close
				Process.wait(pid) if pid
			end
		end
	end
end
