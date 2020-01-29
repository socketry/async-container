# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require "async/container/controller"

RSpec.describe Async::Container::Controller do
	describe '#reload' do
		it "can reuse keyed child" do
			input, output = IO.pipe
			
			subject.instance_variable_set(:@output, output)
			
			def subject.setup(container)
				container.spawn(key: "test") do
					@output.write(".")
					@output.flush
					
					sleep(0.1)
				end
				
				container.spawn do
					# Introduce some "determinism"...
					sleep(0.001)
					
					@output.write(",")
					@output.flush
				end
			end
			
			subject.start
			expect(input.read(2)).to be == ".,"
			
			subject.reload
			
			expect(input.read(1)).to be == ","
			subject.wait
		end
	end
	
	describe '#start' do
		it "can start up a container" do
			expect(subject).to receive(:setup)
			
			subject.start
			
			expect(subject).to be_running
			expect(subject.container).to_not be_nil
			
			subject.stop
			
			expect(subject).to_not be_running
			expect(subject.container).to be_nil
		end
		
		it "can spawn a reactor" do
			def subject.setup(container)
				container.async do |task|
					task.sleep 1
				end
			end
			
			subject.start
			
			statistics = subject.container.statistics
			
			expect(statistics.spawns).to be == 1
			
			subject.stop
		end
	end
end
