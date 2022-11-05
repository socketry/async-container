# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2021, by Samuel Williams.

require 'async/rspec/reactor'

RSpec.shared_examples_for Async::Container do
	it "can run concurrently" do
		input, output = IO.pipe
		
		subject.async do
			output.write "Hello World"
		end
		
		subject.wait
		
		output.close
		expect(input.read).to be == "Hello World"
	end
	
	it "can run concurrently" do
		subject.async(name: "Sleepy Jerry") do |task, instance|
			3.times do |i|
				instance.name = "Counting Sheep #{i}"
				
				sleep 0.01
			end
		end
		
		subject.wait
	end
	
	it "should be blocking", if: Fiber.respond_to?(:blocking?) do
		input, output = IO.pipe
		
		subject.spawn do
			output.write(Fiber.blocking? != false)
		end
		
		subject.wait
		
		output.close
		expect(input.read).to be == "true"
	end
	
	describe '#sleep' do
		it "can sleep for a short time" do
			subject.spawn do
				sleep(0.2 * QUANTUM)
				raise "Boom"
			end
			
			subject.sleep(0.1 * QUANTUM)
			expect(subject.statistics).to have_attributes(failures: 0)
			
			subject.wait
			
			expect(subject.statistics).to have_attributes(failures: 1)
		end
	end
	
	describe '#stop' do
		it 'can stop the child process' do
			subject.spawn do
				sleep(1)
			end
			
			is_expected.to be_running
			
			subject.stop
			
			is_expected.to_not be_running
		end
	end
end
