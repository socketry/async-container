# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require "async/container/controller"
require "async/container/notify/server"

require "async"

describe Async::Container::Notify do
	let(:server) {subject::Server.open}
	let(:notify_socket) {server.path}
	let(:client) {subject::Socket.new(notify_socket)}
	
	it "can send and receive messages" do
		context = server.bind
		
		client.send(true: true, false: false, hello: "world")
		
		message = context.receive
		
		expect(message).to be == {true: true, false: false, hello: "world"}
	end
	
	with "#ready!" do
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
				
				expect(messages.last).to have_keys(
					ready: be == true
				)
			ensure
				context&.close
				Process.wait(pid) if pid
			end
		end
	end
	
	with "#send" do
		it "sends message" do
			context = server.bind
			
			client.send(hello: "world")
			
			message = context.receive
			
			expect(message).to be == {hello: "world"}
		end
		
		it "fails if the message is too big" do
			context = server.bind
			
			expect do
				client.send(test: "x" * (subject::Socket::MAXIMUM_MESSAGE_SIZE+1))
			end.to raise_exception(ArgumentError, message: be =~ /Message length \d+ exceeds \d+/)
		end
	end
	
	with "#stopping!" do
		it "sends stopping message" do
			context = server.bind
			
			client.stopping!
			
			message = context.receive
			
			expect(message).to have_keys(
				stopping: be == true
			)
		end
	end
	
	with "#error!" do
		it "sends error message" do
			context = server.bind
			
			client.error!("Boom!")
			
			message = context.receive
			
			expect(message).to have_keys(
				status: be == "Boom!",
				errno: be == -1,
			)
		end
	end	
end if Async::Container.fork?
