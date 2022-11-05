# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

require "async/container/controller"
require "async/container/notify/server"

return unless Async::Container.fork?

describe Async::Container::Notify do
	let(:server) {subject::Server.open}
	let(:notify_socket) {server.path}
	let(:client) {subject::Socket.new(notify_socket)}
	
	with '#ready!' do
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
				
				expect(messages.last).to have_keys(ready: be == true)
			ensure
				context&.close
				Process.wait(pid) if pid
			end
		end
	end
end
