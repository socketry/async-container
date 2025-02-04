# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "async"

module Async
	module Container
		AContainer = Sus::Shared("a container") do
			let(:container) {subject.new}
			
			with "#run" do
				it "can run several instances concurrently" do
					container.run do
						sleep(1)
					end
					
					expect(container).to be(:running?)
					
					container.stop(true)
					
					expect(container).not.to be(:running?)
				end
				
				it "can stop an uncooperative child process" do
					container.run do
						while true
							begin
								sleep(1)
							rescue Interrupt
								# Ignore.
							end
						end
					end
					
					expect(container).to be(:running?)
					
					# TODO Investigate why without this, the interrupt can occur before the process is sleeping...
					sleep 0.001
					
					container.stop(true)
					
					expect(container).not.to be(:running?)
				end
			end
			
			with "#async" do
				it "can run concurrently" do
					input, output = IO.pipe
					
					container.async do
						output.write "Hello World"
					end
					
					container.wait
					
					output.close
					expect(input.read).to be == "Hello World"
				end
				
				it "can run concurrently" do
					container.async(name: "Sleepy Jerry") do |task, instance|
						3.times do |i|
							instance.name = "Counting Sheep #{i}"
							
							sleep 0.01
						end
					end
					
					container.wait
				end
			end
			
			it "should be blocking" do
				skip "Fiber.blocking? is not supported!" unless Fiber.respond_to?(:blocking?)
				
				input, output = IO.pipe
				
				container.spawn do
					output.write(Fiber.blocking? != false)
				end
				
				container.wait
				
				output.close
				expect(input.read).to be == "true"
			end
			
			with "#sleep" do
				it "can sleep for a short time" do
					container.spawn do
						sleep(0.01)
						raise "Boom"
					end
					
					expect(container.statistics).to have_attributes(failures: be == 0)
					
					container.wait
					
					expect(container.statistics).to have_attributes(failures: be == 1)
				end
			end
			
			with "#stop" do
				it "can gracefully stop the child process" do
					container.spawn do
						sleep(1)
					rescue Interrupt
						# Ignore.
					end
					
					expect(container).to be(:running?)
					
					# See above.
					sleep 0.001
					
					container.stop(true)
					
					expect(container).not.to be(:running?)
				end
				
				it "can forcefully stop the child process" do
					container.spawn do
						sleep(1)
					rescue Interrupt
						# Ignore.
					end
					
					expect(container).to be(:running?)
					
					# See above.
					sleep 0.001
					
					container.stop(false)
					
					expect(container).not.to be(:running?)
				end
				
				it "can stop an uncooperative child process" do
					container.spawn do
						while true
							begin
								sleep(1)
							rescue Interrupt
								# Ignore.
							end
						end
					end
					
					expect(container).to be(:running?)
					
					# See above.
					sleep 0.001
					
					container.stop(true)
					
					expect(container).not.to be(:running?)
				end
			end
			
			with "#ready" do
				it "can notify the ready pipe in an asynchronous context" do
					container.run do |instance|
						Async do
							instance.ready!
						end
					end
					
					expect(container).to be(:running?)
					
					container.wait
					
					container.stop
					
					expect(container).not.to be(:running?)
				end
			end
		end
	end
end
