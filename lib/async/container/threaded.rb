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

module Async
	module Container
		# Manages a reactor within one or more threads.
		class Threaded
			class Instance
				def initialize(thread)
					@thread = thread
				end
				
				def name= value
					@thread.name = value
				end
			end
			
			def self.run(*args, &block)
				self.new.run(*args, &block)
			end
			
			def initialize
				@reactors = []
				@threads = []
			end
			
			def run(threads: Container.processor_count, **options, &block)
				threads.times do
					async(**options, &block)
				end
				
				return self
			end
			
			def async(name: nil, &block)
				reactor = Async::Reactor.new
				
				@reactors << reactor
				
				@threads << ::Thread.new do
					thread = ::Thread.current
					
					thread.abort_on_exception = true
					thread.name = name if name
					
					begin
						reactor.run(Instance.new(thread), &block)
					rescue Interrupt
						# Graceful exit.
					end
				end
				
				return self
			end
			
			def self.multiprocess?
				false
			end
			
			def wait
				@threads.each(&:join)
				@threads.clear
				
				return nil
			end
			
			def stop
				@reactors.each(&:stop)
				@reactors.clear
				
				wait
			end
		end
	end
end
