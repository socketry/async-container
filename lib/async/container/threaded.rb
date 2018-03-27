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

require 'async/reactor'
require 'thread'

require 'async/io/notification'

module Async
	module Container
		# Manages a reactor within one or more threads.
		class Threaded
			def initialize(concurrency: 1, &block)
				@reactors = concurrency.times.collect do
					Async::Reactor.new
				end
				
				@threads = @reactors.collect do |reactor|
					Thread.new do
						Thread.current.abort_on_exception = true
						
						begin
							reactor.run(&block)
						rescue Interrupt
							# Exit cleanly.
						end
					end
				end
				
				@finished = nil
			end
			
			def wait
				return if @finished
				
				@threads.each(&:join)
					
				@finished = true
			end
			
			def stop
				@reactors.each(&:stop)
				
				wait
			end
		end
	end
end
