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
	
	with "#close" do
		it "can close more than once" do
			channel.close
			
			expect do
				channel.close
			end.not.to raise_exception
		end
		
		it "can close the input end after it was already closed" do
			channel.in.close
			
			expect do
				channel.close_read
			end.not.to raise_exception
		end
		
		it "can close the output end after it was already closed" do
			channel.out.close
			
			expect do
				channel.close_write
			end.not.to raise_exception
		end
	end
	
	with "timeout" do
		let(:channel) {subject.new(timeout: 0.001)}
		
		it "fails gracefully on timeout" do
			expect(channel.receive).to be_nil
		end
	end
end
