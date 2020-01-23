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

require_relative 'thread'
require_relative '../group'
require_relative '../error'

module Async
	module Container
		module Threaded
			class Group < Async::Container::Group
				def initialize
					@finished = Thread::Queue.new
					
					super
				end
				
				def finished(*arguments)
					@finished.push(arguments)
				end
				
				def spawn(*arguments, **options)
					fork do
						begin
							pid = ::Process.spawn(*arguments)
							
							::Process.waitpid(pid)
						ensure
							::Process.kill(:TERM, pid)
						end
					end
				end
				
				def fork(**options, &block)
					self.yield
					
					thread = Thread.new(self, **options, &block)
					
					return thread
				end
				
				def kill(exception)
					@running.each_key do |thread|
						thread.raise(exception)
					end
				end
				
				def interrupt
					kill(Interrupt)
				end
				
				def terminate
					kill(Terminate)
				end
				
				protected
				
				# Wait for one process, should only be called when a child process has finished, otherwise would block.
				def wait_one(blocking = true)
					return if @running.empty?
					
					return if !blocking && @finished.empty?
					
					# Wait for threads in this group:
					thread, status = @finished.pop
					
					fiber = @running.delete(thread)
					
					# Join the thread without raising any exceptions:
					thread.finish
					
					if block_given?
						yield fiber, status
					else
						fiber.resume(status)
					end
				end
			end
		end
	end
end
