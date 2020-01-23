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

require 'thread'

module Async
	module Container
		module Threaded
			class Thread < ::Thread
				def initialize(group, name: nil, &block)
					@group = group
					
					if name
						self.name = name
					end
					
					@status = nil
					
					super do
						yield self
					end
					
					# I tried putting this block into the thread itself, but if the user cancels the thread before it even starts, `self.finished` is never called. By using a 2nd thread, we will capture all scenarios that cause the thread to exit in a determanistic way.
					@waiter = ::Thread.new do
						begin
							self.join
						rescue Interrupt
							# Graceful shutdown.
						rescue StandardError => error
							self.finished(error)
						else
							self.finished
						end
					end
				end
				
				def finish
					@waiter.join
				end
				
				def stop
					self.raise(Interrupt)
				end
				
				def wait
					@status ||= @group.wait_for(self)
				end
				
				protected
				
				def finished(result = nil)
					@group.finished(self, Status.new(result))
				end
			end
			
			class Status
				def initialize(result = nil)
					@result = result
				end
				
				def success?
					@result.nil?
				end
			end
		end
	end
end
