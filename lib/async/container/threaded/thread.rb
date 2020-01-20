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
						begin
							yield self
						ensure
							finished
						end
					end
				end
				
				def kill
					raise NotImplementedError
				end
				
				def stop
					self.raise(Interrupt)
					
					self.wait
				end
				
				def wait
					@status ||= @group.wait_for(self)
				end
				
				protected
				
				def finished(result = $!)
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
