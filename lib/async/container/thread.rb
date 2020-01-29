# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'channel'

require 'async/logger'

module Async
	module Container
		class Thread < Channel
			def self.fork(**options)
				self.new(**options) do |thread|
					::Thread.new do
						yield thread
					end
				end
			end
			
			def initialize(name: nil)
				super()
				
				@status = nil
				
				@thread = yield(self)
				@thread.report_on_exception = false
				@thread.name = name
				
				@waiter = ::Thread.new do
					begin
						@thread.join
					rescue Interrupt
						# Graceful shutdown.
						finished
					rescue Exception => error
						finished(error)
					else
						finished
					end
				end
			end
			
			def name= value
				@thread.name = name
			end
			
			def name
				@thread.name
			end
			
			def to_s
				if @status
					"\#<#{self.class} #{@thread.name} -> #{@status}>"
				else
					"\#<#{self.class} #{@thread.name}>"
				end
			end
			
			def close
				self.terminate!
				self.wait
			ensure
				super
			end
			
			def interrupt!
				raise ArgumentError, "Cannot invoke from worker thread!" if @thread == ::Thread.current
				
				@thread.raise(Interrupt)
			end
			
			def terminate!
				raise ArgumentError, "Cannot invoke from worker thread!" if @thread == ::Thread.current
				
				@thread.raise(Terminate)
			end
			
			def wait
				raise ArgumentError, "Cannot invoke from worker thread!" if @thread == ::Thread.current
				
				if @waiter
					@waiter.join
					@waiter = nil
				end
				
				return @status
			end
			
			class Status
				def initialize(result = nil)
					@result = result
				end
				
				def success?
					@result.nil?
				end
				
				def to_s
					"\#<#{self.class} #{success? ? "success" : "failure"}>"
				end
			end
			
			protected
			
			def finished(error = nil)
				if error
					Async.logger.error(self) {error}
				end
				
				@status = Status.new(error)
				@out.close
			end
		end
	end
end
