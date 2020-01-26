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

require 'fiber'

module Async
	module Container
		class Group
			def initialize(notify: false)
				@running = {}
				
				# This queue allows us to wait for processes to complete, without spawning new processes as a result.
				@queue = nil
				
				if notify == true
					@notify = Notify::Server.open
				elsif notify
					@notify = notify
				else
					@notify = nil
				end
				
				@context = @notify&.context
			end
			
			def any?
				@running.any?
			end
			
			def empty?
				@running.empty?
			end
			
			# This method sleeps for the specified duration, then 
			def sleep(duration)
				self.resume
				self.suspend
				
				self.wait_for_children(duration)
				
				# This waits for any process to exit.
				while self.wait_one(false)
				end
			end
			
			def wait
				self.resume
				
				while self.any?
					self.wait_one
				end
			end
			
			def stop(timeout = 1)
				# Handle legacy `graceful = true` argument:
				if timeout == true
					timeout = 1
				end
				
				# Timeout can also be `graceful = false`:
				if timeout
					self.interrupt
					self.sleep(timeout)
				end
			ensure
				self.close
			end
			
			def close
				self.terminate
				self.interrupt_all
				
				@context&.close
			end
			
			protected
			
			def wait_for_children(duration)
				if @notify
					self.wait_until_ready(duration)
				elsif duration
					Kernel::sleep(duration)
				end
			end
			
			def wait_until_ready(duration)
				puts "Waiting on #{@context.pids}"
				
				Sync do |task|
					waiting_task = nil
					
					receiving_task = task.async do
						@context.receive do |message, address|
							pp message
							
							yield message
							
							break if @context.ready?
						end
						
						waiting_task&.stop
					end
					
					if duration
						waiting_task = task.async do |subtask|
							subtask.sleep(duration)
							receiving_task.stop
						end
					end
				end
			end
			
			def yield
				if @queue
					fiber = Fiber.current
					
					@queue << fiber
					Fiber.yield
				end
			end
			
			def suspend
				@queue ||= []
			end
			
			def resume
				if @queue
					queue = @queue
					@queue = nil
					
					queue.each(&:resume)
				end
			end
			
			def interrupt_all
				while self.any?
					self.wait_one do |fiber, status|
						begin
							# This causes the waiting fiber to `raise Interrupt`:
							fiber.resume(nil)
						rescue Interrupt
							# Graceful exit.
						end
					end
				end
			end
			
			public
			
			def wait_for(value)
				@running[value] = Fiber.current
				
				# Return process status:
				if result = Fiber.yield
					return result
				else
					raise Interrupt
				end
			end
		end
	end
end
