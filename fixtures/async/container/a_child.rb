# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Async
	module Container
		AChild = Sus::Shared("a child") do
			def wait_for_child_started(input)
				input.gets
			end
			
			def start_ready_child
				subject.call(name: "test-child") do |instance|
					instance.ready!(status: "ready")
				end
			end
			
			def start_sleeping_child
				::IO.pipe do |input, output|
					child = subject.call(name: "test-child") do
						output.puts "ready"
						sleep
					rescue Interrupt
						# Graceful shutdown.
					end
					
					wait_for_child_started(input)
					
					return child
				end
			end
			
			def start_uncooperative_child
				::IO.pipe do |input, output|
					child = subject.call(name: "test-child") do
						ready_sent = false
						
						loop do
							begin
								unless ready_sent
									output.puts "ready"
									ready_sent = true
								end
								
								sleep
							rescue Interrupt
								# Ignore graceful shutdown.
							end
						end
					end
					
					wait_for_child_started(input)
					
					return child
				end
			end
			
			it "receives notifications and returns a successful status" do
				child = start_ready_child
				
				messages = []
				status = child.wait do |message|
					messages << message
				end
				
				expect(messages).to be == [{ready: true, status: "ready"}]
				expect(status).to be(:success?)
			end
			
			it "tracks when the child last sent a message" do
				child = start_ready_child
				last_updated_at = child.last_updated_at
				
				messages = []
				child.wait do |message|
					messages << message
				end
				
				expect(messages).to be == [{ready: true, status: "ready"}]
				expect(child.last_updated_at).to be >= last_updated_at
			end
			
			it "can receive messages until the child is ready" do
				child = subject.call(name: "test-child") do |instance|
					instance.ready!(status: "ready")
					sleep
				rescue Interrupt
					# Graceful shutdown.
				end
				
				result = child.receive do
					break :ready if child.ready?
				end
				
				expect(result).to be == :ready
				expect(child).to be(:ready?)
				
				status = child.stop(true)
				
				expect(status).to be(:success?)
			end
			
			it "returns a successful status for normal exit" do
				child = subject.call(name: "test-child") do
					# Exit normally.
				end
				
				status = child.wait
				
				expect(status).to be(:success?)
			end
			
			it "returns nil when wait times out" do
				child = start_sleeping_child
				last_updated_at = child.last_updated_at
				
				expect(child.wait(0.001)).to be_nil
				expect(child.last_updated_at).to be == last_updated_at
				
				status = child.stop(false)
				
				expect(status).not.to be(:success?)
			end
			
			it "can stop gracefully" do
				child = start_sleeping_child
				
				status = child.stop(true)
				
				expect(status).to be(:success?)
			end
			
			it "can kill immediately" do
				child = start_sleeping_child
				
				status = child.stop(false)
				
				expect(status).not.to be(:success?)
			end
			
			it "kills the child when graceful shutdown times out" do
				child = start_uncooperative_child
				
				status = child.stop(0.001)
				
				expect(status).not.to be(:success?)
			end
			
			it "returns a failure status when the child fails" do
				child = subject.call(name: "test-child") do
					raise "boom"
				end
				
				status = child.wait
				
				expect(status).not.to be(:success?)
			end
		end
	end
end
