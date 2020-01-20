# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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
				puts "Counting Sheep #{i}"
				instance.name = "Counting Sheep #{i}"
				
				sleep 0.01
			end
		end
		
		subject.wait
	end
	
	describe '#sleep' do
		it "can sleep for a short time" do
			subject.spawn do
				puts "Sleep(2)"
				sleep(2)
				puts "Boom"
				raise "Boom"
			end
			
			puts "Sleep(1)"
			subject.sleep(1)
			puts "Failures?"
			expect(subject.statistics).to have_attributes(failures: 0)
			
			subject.wait
			
			expect(subject.statistics).to have_attributes(failures: 1)
		end
	end
end
