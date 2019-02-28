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

require_relative 'forked'
require_relative 'threaded'

module Async
	# Manages a reactor within one or more threads.
	module Container
		class Hybrid
			def self.run(*args, &block)
				self.new.run(*args, &block)
			end
			
			def initialize
				@container = Forked.new
			end
			
			def run(processes: Container.processor_count, threads: nil, **options, &block)
				threads ||= processes
				
				processes.times do
					@container.spawn(**options) do
						container = Threaded.new
						
						container.run(threads: threads, **options, &block)
						
						container.wait
					end
				end
				
				return self
			end
			
			def async(**options, &block)
				@container.async(**options, &block)
			end
			
			def self.multiprocess?
				true
			end
			
			def wait
				@container.wait
			end
			
			def stop(*args)
				@container.stop(*args)
			end
		end
	end
end
