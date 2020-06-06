# frozen_string_literal: true

# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

RSpec.describe Async::Container do
	describe '.processor_count' do
		it "can get processor count" do
			expect(Async::Container.processor_count).to be >= 1
		end
		
		it "can override the processor count" do
			env = {'ASYNC_CONTAINER_PROCESSOR_COUNT' => '8'}
			
			expect(Async::Container.processor_count(env)).to be == 8
		end
		
		it "fails on invalid processor count" do
			env = {'ASYNC_CONTAINER_PROCESSOR_COUNT' => '-1'}
			
			expect do
				Async::Container.processor_count(env)
			end.to raise_error(/Invalid processor count/)
		end
	end
	
	it "can get best container class" do
		expect(Async::Container.best_container_class).to_not be_nil
	end
	
	subject {Async::Container.new}
	
	it "can get best container class" do
		expect(subject).to_not be_nil
		
		subject.stop
	end
end
