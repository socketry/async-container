# frozen_string_literal: true

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

require "async/container"
require "async/container/forked"

require_relative 'shared_examples'

RSpec.describe Async::Container::Forked, if: Async::Container.fork? do
	subject {described_class.new}
	
	it_behaves_like Async::Container
	
	it "can restart child" do
		trigger = IO.pipe
		pids = IO.pipe
		
		thread = Thread.new do
			subject.async(restart: true) do
				trigger.first.gets
				pids.last.puts Process.pid.to_s
			end
			
			subject.wait
		end
		
		3.times do
			trigger.last.puts "die"
			_child_pid = pids.first.gets
		end
		
		thread.kill
		thread.join
		
		expect(subject.statistics.spawns).to be == 1
		expect(subject.statistics.restarts).to be == 2
	end
	
	it "should be multiprocess" do
		expect(described_class).to be_multiprocess
	end
end
