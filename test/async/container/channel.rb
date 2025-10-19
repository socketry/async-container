# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/channel"

describe Async::Container::Channel do
	let(:channel) {subject.new}
	
	after do
		@channel&.close
	end
	
	it "can send and receive" do
		channel.out.puts "Hello, World!"
		
		expect(channel.in.gets).to be == "Hello, World!\n"
	end
	
	it "can send and receive JSON" do
		channel.out.puts JSON.dump({hello: "world"})
		
		expect(channel.receive).to be == {hello: "world"}
	end
	
	it "ignores invalid JSON" do
		channel.out.puts "Hello, World!"
		
		expect(channel.receive).to be_nil
	end
	
	with "timeout" do
		let(:channel) {subject.new(timeout: 0.001)}
		
		it "fails gracefully on timeout" do
			expect(channel.receive).to be_nil
		end
	end
end
