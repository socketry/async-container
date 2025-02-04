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
	
	it "can receive invalid JSON" do
		channel.out.puts "Hello, World!"
		
		expect(channel.receive).to be == {line: "Hello, World!\n"}
	end
end
